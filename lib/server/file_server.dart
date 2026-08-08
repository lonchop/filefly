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

/// A file kept in the shared folder, as shown to both the app and the phone.
class SharedFile {
  const SharedFile({required this.name, required this.path, required this.size, required this.modified});

  final String name;
  final String path;
  final int size;
  final DateTime modified;
}

/// The HTTP server the phone talks to. The desktop window is a native client
/// of the same shared folder, so nothing on screen goes through this.
class FileServer {
  FileServer({required this.indexHtml, required this.token, required Directory sharedDirectory})
      : _sharedDirectory = sharedDirectory;

  /// The page served to phones. Held as a string so this layer stays free of
  /// Flutter asset plumbing.
  final String indexHtml;
  final String token;

  Directory _sharedDirectory;
  HttpServer? _server;
  List<String> _shareUrls = const [];

  final _changes = StreamController<void>.broadcast();

  /// Fires whenever a phone adds or removes a file.
  Stream<void> get changes => _changes.stream;

  Directory get sharedDirectory => _sharedDirectory;

  set sharedDirectory(Directory value) {
    _sharedDirectory = value..createSync(recursive: true);
    _changes.add(null);
  }

  bool get isRunning => _server != null;

  int? get port => _server?.port;

  /// Full URLs, token included, that a phone can open. The QR encodes the first.
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
          // The client hung up mid-response; nothing left to say.
        }
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final query = request.uri.queryParameters;

    if (request.method == 'GET' && path == '/') {
      if (_tokenInQueryIsValid(query)) {
        // Park the token in a cookie and bounce to a clean URL, so it stops
        // sitting in the address bar and the browser history.
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
      case ('GET', '/api/config'):
        await _sendJson(request, {
          'port': _server?.port,
          'urls': _shareUrls,
          'hostname': Platform.localHostname,
        });
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

  // -- routes ----------------------------------------------------------------

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
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.binary
      ..headers.set('content-disposition',
          "attachment; filename*=UTF-8''${Uri.encodeComponent(name)}")
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..contentLength = await file.length();

    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  Future<void> _handleDelete(HttpRequest request, Map<String, String> query) async {
    final file = await _resolveQueryFile(request, query);
    if (file == null) return;

    await file.delete();
    _changes.add(null);
    await _sendJson(request, {'ok': true});
  }

  /// Returns an existing file inside the shared folder, or null after replying.
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

  // -- shared folder ---------------------------------------------------------

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

  /// Copies a file the desktop user picked into the shared folder.
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

  // -- auth ------------------------------------------------------------------

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

  // -- responses -------------------------------------------------------------

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

/// Reduces any name to a plain file name, so nothing can be written or read
/// outside the shared folder.
String safeFileName(String name) {
  var base = p.basename(name.replaceAll(r'\', '/')).trim();
  base = base.replaceAll(RegExp(r'[\x00-\x1f/:*?"<>|]'), '_');
  if (base.isEmpty || base == '.' || base == '..') return 'archivo.bin';
  return base;
}

/// Compares two secrets without leaking their common prefix through timing.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
