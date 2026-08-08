import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Where FileFly keeps its token and its settings, per platform convention.
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

/// The access token, reused across runs.
///
/// Regenerating it on every launch would silently invalidate the QR code, the
/// saved link and the cookie of every phone that already paired, leaving no
/// way back in. [rotate] is the deliberate "lock everyone out" path.
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
    // Dart cannot chmod; the token is a secret, so keep it owner-only.
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
