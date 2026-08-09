import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../server/app_paths.dart';
import '../server/file_server.dart';
import 'widgets/connect_panel.dart';
import 'widgets/send_panel.dart';
import 'widgets/shared_files_panel.dart';

const _defaultPort = 8765;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.indexHtml});

  final String indexHtml;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FileServer? _server;
  StreamSubscription<void>? _changes;
  List<SharedFile> _files = const [];
  String? _startupError;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _changes?.cancel();
    unawaited(_server?.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final server = FileServer(
        indexHtml: widget.indexHtml,
        token: await loadToken(),
        sharedDirectory: await loadSharedDirectory(),
      );
      await server.start(port: _defaultPort);
      _changes = server.changes.listen((_) => unawaited(_refresh()));
      if (!mounted) {
        await server.dispose();
        return;
      }
      setState(() => _server = server);
      await _refresh();
    } on Object catch (error) {
      if (mounted) setState(() => _startupError = '$error');
    }
  }

  Future<void> _refresh() async {
    final files = await _server?.listFiles() ?? const <SharedFile>[];
    if (mounted) setState(() => _files = files);
  }

  Future<void> _addFiles(List<String> paths) async {
    final server = _server;
    if (server == null) return;

    for (final path in paths) {
      if (FileSystemEntity.isDirectorySync(path)) continue; // folders are not shared
      await server.addLocalFile(path);
    }
    await _refresh();
  }

  Future<void> _changeFolder() async {
    final server = _server;
    if (server == null) return;

    final picked = await getDirectoryPath(
      confirmButtonText: 'Compartir',
    );
    if (picked == null) return;

    final dir = Directory(picked);
    server.sharedDirectory = dir;
    await saveSharedDirectory(dir);
    await _refresh();
  }

  /// Hands a path to the desktop environment; there is no Dart API for this.
  Future<void> _openInDesktop(String path) async {
    final command = Platform.isWindows ? 'explorer' : 'xdg-open';
    await Process.run(command, [path]);
  }

  Future<void> _deleteFile(SharedFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar archivo'),
        content: Text('Se va a borrar "${file.name}" de la carpeta compartida.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _server?.deleteFile(file.path);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final server = _server;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(running: server?.isRunning ?? false),
                  const SizedBox(height: 28),
                  if (_startupError != null)
                    _ErrorCard(message: _startupError!)
                  else if (server == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    // Both cards size to their own content. A shared height
                    // would need IntrinsicHeight, and the drop zone's Expanded
                    // gives that no intrinsic height to work with.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: SendPanel(onFilesChosen: _addFiles)),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 420,
                          child: ConnectPanel(shareUrls: server.shareUrls),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SharedFilesPanel(
                      files: _files,
                      folderPath: server.sharedDirectory.path,
                      onRefresh: _refresh,
                      onOpenFolder: () => _openInDesktop(server.sharedDirectory.path),
                      onChangeFolder: _changeFolder,
                      onOpenFile: (file) => _openInDesktop(file.path),
                      onDeleteFile: _deleteFile,
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Los archivos se transfieren por tu red local. Nada sale a internet.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FileFly',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, height: 1.1)),
              SizedBox(height: 8),
              Text(
                'Transfiere archivos entre la PC y el celular. Sin cable, sin nube '
                'y sin instalar nada en el telefono.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: running ? AppColors.accent : AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(running ? 'Servidor local activo' : 'Servidor detenido',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No se pudo iniciar el servidor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SelectableText(message, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 10),
          const Text(
            'Revisa que el puerto $_defaultPort no este ocupado por otra instancia.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
