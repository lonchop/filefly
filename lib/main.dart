import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/palette.dart';
import 'app/theme.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The page phones load. Read once here so the server layer never touches
  // Flutter's asset bundle, and stamped with the same palette the window uses.
  final indexHtml = withPaletteTokens(
    await rootBundle.loadString('assets/web/index.html'),
  );

  runApp(FileFlyApp(
    indexHtml: indexHtml,
    publicAssets: {
      '/manifest.webmanifest': (
        contentType: 'application/manifest+json; charset=utf-8',
        bytes: utf8.encode(buildWebManifest()),
      ),
      '/icon-256.png': (contentType: 'image/png', bytes: await _loadBytes('filefly-256')),
      '/icon-512.png': (contentType: 'image/png', bytes: await _loadBytes('filefly-512')),
    },
  ));
}

Future<Uint8List> _loadBytes(String icon) async {
  final data = await rootBundle.load('assets/icons/$icon.png');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

class FileFlyApp extends StatelessWidget {
  const FileFlyApp({super.key, required this.indexHtml, required this.publicAssets});

  final String indexHtml;
  final Map<String, ({String contentType, List<int> bytes})> publicAssets;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FileFly',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(indexHtml: indexHtml, publicAssets: publicAssets),
    );
  }
}
