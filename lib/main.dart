import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/theme.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The page phones load. Read once here so the server layer never touches
  // Flutter's asset bundle.
  final indexHtml = await rootBundle.loadString('assets/web/index.html');

  runApp(FileFlyApp(indexHtml: indexHtml));
}

class FileFlyApp extends StatelessWidget {
  const FileFlyApp({super.key, required this.indexHtml});

  final String indexHtml;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FileFly',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(indexHtml: indexHtml),
    );
  }
}
