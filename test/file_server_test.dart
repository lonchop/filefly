import 'dart:convert';
import 'dart:io';

import 'package:filefly/server/file_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _indexHtml = '<!doctype html><title>FileFly</title>';

void main() {
  late Directory shared;
  late FileServer server;
  late HttpClient client;
  late String base;

  setUp(() async {
    shared = await Directory.systemTemp.createTemp('filefly_test');
    server = FileServer(indexHtml: _indexHtml, token: _token, sharedDirectory: shared);
    await server.start(port: 0);
    client = HttpClient()..userAgent = 'filefly-test';
    base = 'http://127.0.0.1:${server.port}';
  });

  tearDown(() async {
    client.close(force: true);
    await server.dispose();
    await shared.delete(recursive: true);
  });

  Future<HttpClientResponse> send(
    String method,
    String path, {
    List<int>? body,
    Map<String, String> headers = const {},
    bool followRedirects = false,
  }) async {
    final request = await client.openUrl(method, Uri.parse('$base$path'));
    request.followRedirects = followRedirects;
    headers.forEach(request.headers.set);
    if (body != null) request.add(body);
    return request.close();
  }

  test('rejects a request with the wrong token', () async {
    final response = await send('GET', '/api/files?token=wrong');
    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test('trades the token in the URL for a cookie and a clean path', () async {
    final response = await send('GET', '/?token=$_token');

    expect(response.statusCode, HttpStatus.found);
    expect(response.headers.value(HttpHeaders.locationHeader), '/');

    final cookie = response.headers.value(HttpHeaders.setCookieHeader)!;
    expect(cookie, contains('filefly_token=$_token'));
    expect(cookie, contains('HttpOnly'));
    // Tiene que sobrevivir a la sesión del navegador, o reiniciar deja al
    // celular fuera.
    expect(cookie, contains('Max-Age='));
  });

  test('serves the page with only the cookie', () async {
    final response = await send('GET', '/', headers: {'cookie': 'filefly_token=$_token'});

    expect(response.statusCode, HttpStatus.ok);
    expect(await response.transform(utf8.decoder).join(), _indexHtml);
  });

  test('rejects a cookie from an earlier run', () async {
    final response = await send('GET', '/api/files', headers: {'cookie': 'filefly_token=viejo'});
    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test('serves the 401 page when nothing is provided', () async {
    final response = await send('GET', '/');
    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test('upload keeps the file inside the shared folder', () async {
    final response = await send(
      'POST',
      '/api/upload?token=$_token',
      body: utf8.encode('hola'),
      headers: {'x-filename': '..%2F..%2Fescape.txt'},
    );

    expect(response.statusCode, HttpStatus.ok);
    await response.drain<void>();
    expect(File(p.join(shared.path, 'escape.txt')).readAsStringSync(), 'hola');
  });

  test('a second upload with the same name does not clobber the first', () async {
    for (final content in ['uno', 'dos']) {
      final response = await send(
        'POST',
        '/api/upload?token=$_token',
        body: utf8.encode(content),
        headers: {'x-filename': 'nota.txt'},
      );
      await response.drain<void>();
    }

    expect(File(p.join(shared.path, 'nota.txt')).readAsStringSync(), 'uno');
    expect(File(p.join(shared.path, 'nota (1).txt')).readAsStringSync(), 'dos');
  });

  test('lists, downloads and deletes', () async {
    File(p.join(shared.path, 'foto.png')).writeAsStringSync('bytes');

    final listed = await send('GET', '/api/files?token=$_token');
    final body = jsonDecode(await listed.transform(utf8.decoder).join());
    expect((body['files'] as List).single['name'], 'foto.png');

    final download = await send('GET', '/api/download?token=$_token&name=foto.png');
    expect(download.statusCode, HttpStatus.ok);
    expect(await download.transform(utf8.decoder).join(), 'bytes');

    final deleted = await send('DELETE', '/api/file?token=$_token&name=foto.png');
    expect(deleted.statusCode, HttpStatus.ok);
    await deleted.drain<void>();
    expect(File(p.join(shared.path, 'foto.png')).existsSync(), isFalse);
  });

  test('serves an image inline so the grid can show a thumbnail', () async {
    File(p.join(shared.path, 'foto.png')).writeAsStringSync('bytes');

    final response = await send('GET', '/api/download?token=$_token&name=foto.png&inline=1');

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType.toString(), 'image/png');
    expect(response.headers.value('content-disposition'), isNull);
    expect(response.headers.value('x-content-type-options'), 'nosniff');
    await response.drain<void>();
  });

  test('never serves anything but a whitelisted image inline', () async {
    // Un HTML servido en línea correría en el mismo origen que la página, con
    // la cookie de sesión de quien lo abriera: podría vaciar la carpeta
    // compartida desde dentro. Esta es la guarda de que `inline` no es un
    // interruptor genérico.
    for (final name in ['pagina.html', 'dibujo.svg', 'script.js', 'nota.txt']) {
      File(p.join(shared.path, name)).writeAsStringSync('<script>alert(1)</script>');

      final response = await send('GET', '/api/download?token=$_token&name=$name&inline=1');

      expect(response.headers.contentType?.mimeType, 'application/octet-stream',
          reason: '$name no debe servirse con un tipo que el navegador ejecute');
      expect(response.headers.value('content-disposition'), contains('attachment'),
          reason: '$name debe bajar como adjunto');
      await response.drain<void>();
    }
  });

  test('refuses to reach outside the shared folder on download', () async {
    final response = await send('GET', '/api/download?token=$_token&name=../../../etc/passwd');
    expect(response.statusCode, HttpStatus.notFound);
  });

  test('safeFileName strips every path component', () {
    expect(safeFileName('../../etc/passwd'), 'passwd');
    expect(safeFileName(r'C:\Windows\system32\evil.dll'), 'evil.dll');
    expect(safeFileName('..'), 'archivo.bin');
    expect(safeFileName(''), 'archivo.bin');
  });
}
