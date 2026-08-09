import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Dónde guarda FileFly su token y sus preferencias, según la convención de
/// cada plataforma.
Directory configDirectory() {
  final env = Platform.environment;
  final String base;
  if (Platform.isWindows) {
    base = env['APPDATA'] ?? p.join(env['USERPROFILE'] ?? '.', 'AppData', 'Roaming');
  } else {
    base = env['XDG_CONFIG_HOME'] ?? p.join(env['HOME'] ?? '.', '.config');
  }
  return Directory(p.join(base, 'filefly'))..createSync(recursive: true);
}

Directory defaultSharedDirectory() {
  final env = Platform.environment;
  final home = (Platform.isWindows ? env['USERPROFILE'] : env['HOME']) ?? '.';
  return Directory(p.join(home, 'FileFly'));
}

File get _tokenFile => File(p.join(configDirectory().path, 'token'));

File get _sharedDirFile => File(p.join(configDirectory().path, 'shared_dir'));

/// El token de acceso, reutilizado entre arranques.
///
/// Regenerarlo en cada lanzamiento invalidaría en silencio el código QR, el
/// enlace guardado y la cookie de todos los celulares ya emparejados, sin
/// ninguna vía de vuelta. [rotate] es el camino deliberado para dejar a todo el
/// mundo fuera.
Future<String> loadToken({bool rotate = false}) async {
  final file = _tokenFile;
  if (!rotate && await file.exists()) {
    final saved = (await file.readAsString()).trim();
    if (saved.isNotEmpty) return saved;
  }

  final random = Random.secure();
  final token = List.generate(32, (_) => '0123456789abcdef'[random.nextInt(16)]).join();
  await file.writeAsString(token);
  if (!Platform.isWindows) {
    // Dart no sabe hacer chmod; el token es un secreto, así que hay que
    // dejarlo accesible solo para su dueño.
    await Process.run('chmod', ['600', file.path]);
  }
  return token;
}

Future<Directory> loadSharedDirectory() async {
  final pointer = _sharedDirFile;
  if (await pointer.exists()) {
    final saved = (await pointer.readAsString()).trim();
    if (saved.isNotEmpty) {
      final dir = Directory(saved);
      if (await dir.exists()) return dir;
    }
  }
  return defaultSharedDirectory()..createSync(recursive: true);
}

Future<void> saveSharedDirectory(Directory dir) =>
    _sharedDirFile.writeAsString(dir.path);
