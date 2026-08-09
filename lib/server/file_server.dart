import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'lan_addresses.dart';

const _cookieName = 'filefly_token';
const _cookieMaxAge = 60 * 60 * 24 * 30;

const _unauthorizedHtml = '''
<!doctype html>
<html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>FileFly</title>
<body style="font-family:system-ui;background:#0b1020;color:#eef4ff;padding:32px;line-height:1.5">
<h1>FileFly</h1>
<p>Esta direccion necesita el token de acceso.</p>
<p>Volve a escanear el codigo QR desde la PC, o usa el enlace completo que
FileFly muestra en pantalla.</p>
</body></html>
''';

/// Un archivo guardado en la carpeta compartida, tal como se le muestra tanto a
/// la app como al celular.
class SharedFile {
  const SharedFile({required this.name, required this.path, required this.size, required this.modified});

  final String name;
  final String path;
  final int size;
  final DateTime modified;
}

/// El servidor HTTP con el que habla el celular. La ventana de escritorio es un
/// cliente nativo de esa misma carpeta compartida, así que nada de lo que está
/// en pantalla pasa por aquí.
class FileServer {
  FileServer({
    required this.indexHtml,
    required this.token,
    required Directory sharedDirectory,
    this.publicAssets = const {},
  }) : _sharedDirectory = sharedDirectory;

  /// La página que se sirve a los celulares. Se guarda como cadena para que
  /// esta capa quede libre de la fontanería de assets de Flutter.
  final String indexHtml;
  final String token;

  /// Archivos que se sirven sin token, indexados por ruta de petición: el logo
  /// y el manifest web. No llevan datos del usuario, y el navegador los pide
  /// fuera del contexto de cookie de la página al instalar un acceso directo en
  /// la pantalla de inicio: protegerlos solo produciría un icono en blanco.
  final Map<String, ({String contentType, List<int> bytes})> publicAssets;

  Directory _sharedDirectory;
  HttpServer? _server;
  List<String> _shareUrls = const [];

  final _changes = StreamController<void>.broadcast();

  /// Emite cada vez que un celular añade o quita un archivo.
  Stream<void> get changes => _changes.stream;

  Directory get sharedDirectory => _sharedDirectory;

  set sharedDirectory(Directory value) {
    _sharedDirectory = value..createSync(recursive: true);
    _changes.add(null);
  }

  bool get isRunning => _server != null;

  int? get port => _server?.port;

  /// URLs completas, token incluido, que un celular puede abrir. El QR codifica
  /// la primera.
  List<String> get shareUrls => _shareUrls;

  Future<void> start({int port = 8765}) async {
    if (_server != null) return;

    _sharedDirectory.createSync(recursive: true);
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    server.defaultResponseHeaders.removeAll('X-Frame-Options');
    _server = server;

    final ips = await lanIpv4Addresses();
    _shareUrls = [
      for (final ip in ips) 'http://$ip:${server.port}/?token=$token',
    ];

    unawaited(_serve(server));
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _shareUrls = const [];
    await server?.close(force: true);
  }

  Future<void> dispose() async {
    await stop();
    await _changes.close();
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _handle(request);
      } catch (_) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {
          // El cliente colgó a mitad de la respuesta; no queda nada que decir.
        }
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final query = request.uri.queryParameters;

    final asset = publicAssets[path];
    if (request.method == 'GET' && asset != null) {
      await _sendBytes(request, asset.bytes, asset.contentType);
      return;
    }

    if (request.method == 'GET' && path == '/') {
      if (_tokenInQueryIsValid(query)) {
        // Deja el token aparcado en una cookie y rebota a una URL limpia, para
        // que deje de estar en la barra de direcciones y en el historial del
        // navegador.
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, '/')
          ..headers.add(HttpHeaders.setCookieHeader,
              '$_cookieName=$token; Path=/; HttpOnly; SameSite=Lax; Max-Age=$_cookieMaxAge');
        await request.response.close();
        return;
      }
      if (!_authorized(request, query)) {
        await _sendHtml(request, _unauthorizedHtml, status: HttpStatus.unauthorized);
        return;
      }
      await _sendHtml(request, indexHtml);
      return;
    }

    if (!_authorized(request, query)) {
      await _sendJson(request, {'error': 'No autorizado.'}, status: HttpStatus.unauthorized);
      return;
    }

    switch ((request.method, path)) {
      case ('GET', '/api/files'):
        await _sendJson(request, {
          'files': [
            for (final file in await listFiles())
              {
                'name': file.name,
                'size': file.size,
                'modified': file.modified.toUtc().toIso8601String(),
              },
          ],
        });
      case ('POST', '/api/upload'):
        await _handleUpload(request);
      case ('GET', '/api/download'):
        await _handleDownload(request, query);
      case ('DELETE', '/api/file'):
        await _handleDelete(request, query);
      default:
        await _sendJson(request, {'error': 'Ruta no encontrada.'}, status: HttpStatus.notFound);
    }
  }

  // -- rutas -----------------------------------------------------------------

  Future<void> _handleUpload(HttpRequest request) async {
    final rawName = request.headers.value('x-filename') ?? 'archivo.bin';
    final target = uniqueTarget(Uri.decodeComponent(rawName));

    try {
      final sink = target.openWrite();
      try {
        await sink.addStream(request);
      } finally {
        await sink.close();
      }
    } on Object catch (error) {
      if (await target.exists()) await target.delete();
      await _sendJson(request, {'error': '$error'}, status: HttpStatus.internalServerError);
      return;
    }

    _changes.add(null);
    await _sendJson(request, {
      'ok': true,
      'name': p.basename(target.path),
      'size': await target.length(),
    });
  }

  Future<void> _handleDownload(HttpRequest request, Map<String, String> query) async {
    final file = await _resolveQueryFile(request, query);
    if (file == null) return;

    final name = p.basename(file.path);
    // La vista de cuadrícula pide el archivo con `inline=1` para pintarlo como
    // miniatura. Solo se responde así a las imágenes: un HTML servido en línea
    // correría en el mismo origen que la página y podría llamar a la API con la
    // cookie de sesión de quien lo abriera. Todo lo demás baja como adjunto,
    // que es inerte.
    final inlineType = query['inline'] == '1' ? imageContentType(name) : null;
    final response = request.response
      ..statusCode = HttpStatus.ok
      ..contentLength = await file.length();

    if (inlineType == null) {
      response
        ..headers.contentType = ContentType.binary
        ..headers.set('content-disposition',
            "attachment; filename*=UTF-8''${Uri.encodeComponent(name)}")
        ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    } else {
      response
        ..headers.set(HttpHeaders.contentTypeHeader, inlineType)
        // El tipo lo decide la extensión, así que el navegador no debe olfatear
        // el contenido y llegar a una conclusión distinta.
        ..headers.set('x-content-type-options', 'nosniff')
        // Reordenar la lista repinta la cuadrícula entera; sin caché cada
        // reordenación volvería a bajar todas las fotos.
        ..headers.set(HttpHeaders.cacheControlHeader, 'private, max-age=300');
    }

    await response.addStream(file.openRead());
    await response.close();
  }

  Future<void> _handleDelete(HttpRequest request, Map<String, String> query) async {
    final file = await _resolveQueryFile(request, query);
    if (file == null) return;

    await file.delete();
    _changes.add(null);
    await _sendJson(request, {'ok': true});
  }

  /// Devuelve un archivo existente dentro de la carpeta compartida, o null
  /// después de haber respondido.
  Future<File?> _resolveQueryFile(HttpRequest request, Map<String, String> query) async {
    final name = query['name'];
    if (name == null) {
      await _sendJson(request, {'error': 'Falta nombre.'}, status: HttpStatus.badRequest);
      return null;
    }

    final file = File(p.join(_sharedDirectory.path, safeFileName(name)));
    if (!await file.exists()) {
      await _sendJson(request, {'error': 'Archivo no encontrado.'}, status: HttpStatus.notFound);
      return null;
    }
    return file;
  }

  // -- carpeta compartida ----------------------------------------------------

  Future<List<SharedFile>> listFiles() async {
    if (!await _sharedDirectory.exists()) return const [];

    final files = <SharedFile>[];
    await for (final entity in _sharedDirectory.list(followLinks: false)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      files.add(SharedFile(
        name: p.basename(entity.path),
        path: entity.path,
        size: stat.size,
        modified: stat.modified,
      ));
    }
    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files;
  }

  /// Copia a la carpeta compartida un archivo que eligió el usuario de
  /// escritorio.
  Future<void> addLocalFile(String sourcePath) async {
    final target = uniqueTarget(p.basename(sourcePath));
    await File(sourcePath).copy(target.path);
    _changes.add(null);
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
    _changes.add(null);
  }

  File uniqueTarget(String requestedName) {
    final safe = safeFileName(requestedName);
    var target = File(p.join(_sharedDirectory.path, safe));
    if (!target.existsSync()) return target;

    final ext = p.extension(safe);
    final stem = p.basenameWithoutExtension(safe);
    var i = 1;
    while (target.existsSync()) {
      target = File(p.join(_sharedDirectory.path, '$stem ($i)$ext'));
      i++;
    }
    return target;
  }

  // -- autorización ----------------------------------------------------------

  bool _tokenInQueryIsValid(Map<String, String> query) =>
      _constantTimeEquals(query['token'] ?? '', token);

  bool _authorized(HttpRequest request, Map<String, String> query) {
    if (_tokenInQueryIsValid(query)) return true;
    for (final cookie in request.cookies) {
      if (cookie.name == _cookieName && _constantTimeEquals(cookie.value, token)) {
        return true;
      }
    }
    return false;
  }

  // -- respuestas ------------------------------------------------------------

  Future<void> _sendHtml(HttpRequest request, String html, {int status = HttpStatus.ok}) async {
    final body = utf8.encode(html);
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..contentLength = body.length
      ..add(body);
    await request.response.close();
  }

  /// Marca que no cambia mientras la app corre, así que se puede cachear.
  Future<void> _sendBytes(HttpRequest request, List<int> bytes, String contentType) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set(HttpHeaders.contentTypeHeader, contentType)
      ..headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=86400')
      ..contentLength = bytes.length
      ..add(bytes);
    await request.response.close();
  }

  Future<void> _sendJson(HttpRequest request, Object body, {int status = HttpStatus.ok}) async {
    final bytes = utf8.encode(jsonEncode(body));
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..contentLength = bytes.length
      ..add(bytes);
    await request.response.close();
  }
}

/// Formatos de imagen que la cuadrícula puede pedir en línea, y su tipo MIME.
///
/// Es una lista blanca, no una tabla de conveniencia: lo que no esté aquí se
/// sirve como adjunto binario. Añadir un formato que el navegador pueda
/// ejecutar (SVG entre ellos, que lleva script) convertiría la carpeta
/// compartida en un vector de XSS contra la propia página.
const _inlineImageTypes = <String, String>{
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.avif': 'image/avif',
  '.bmp': 'image/bmp',
};

/// El tipo MIME con el que se puede servir [name] en línea, o null si no es una
/// imagen de la lista blanca.
String? imageContentType(String name) => _inlineImageTypes[p.extension(name).toLowerCase()];

/// Reduce cualquier nombre a un nombre de archivo plano, para que no se pueda
/// escribir ni leer fuera de la carpeta compartida.
String safeFileName(String name) {
  var base = p.basename(name.replaceAll(r'\', '/')).trim();
  base = base.replaceAll(RegExp(r'[\x00-\x1f/:*?"<>|]'), '_');
  if (base.isEmpty || base == '.' || base == '..') return 'archivo.bin';
  return base;
}

/// Compara dos secretos sin filtrar por tiempos su prefijo común.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
