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
  const HomeScreen({super.key, required this.indexHtml, this.publicAssets = const {}});

  final String indexHtml;
  final Map<String, ({String contentType, List<int> bytes})> publicAssets;

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
        publicAssets: widget.publicAssets,
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
        content: Text('Se borra "${file.name}". No se puede deshacer.'),
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

    // Measured on the window, not on the content box, so the breakpoint means
    // what it says.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < kNarrowWindow;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(narrow ? Space.lg : Space.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(running: server?.isRunning ?? false, narrow: narrow),
                      const SizedBox(height: Space.xl + Space.xs),
                      if (_startupError != null)
                        _ErrorCard(message: _startupError!)
                      else if (server == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _TopPanels(
                          narrow: narrow,
                          send: SendPanel(onFilesChosen: _addFiles, fillHeight: !narrow),
                          connect: ConnectPanel(shareUrls: server.shareUrls),
                        ),
                        const SizedBox(height: Space.xl),
                        SharedFilesPanel(
                          narrow: narrow,
                          files: _files,
                          folderPath: server.sharedDirectory.path,
                          onRefresh: _refresh,
                          onOpenFolder: () => _openInDesktop(server.sharedDirectory.path),
                          onChangeFolder: _changeFolder,
                          onOpenFile: (file) => _openInDesktop(file.path),
                          onDeleteFile: _deleteFile,
                        ),
                      ],
                      const SizedBox(height: Space.xl),
                      const Center(
                        child: Text(
                          'Todo viaja por tu red local. Nada sale a internet.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Send and connect sit side by side while there is room, and stack once the
/// window gets too narrow for the QR plate and a readable drop zone to share
/// a row.
class _TopPanels extends StatelessWidget {
  const _TopPanels({required this.narrow, required this.send, required this.connect});

  final bool narrow;
  final Widget send;
  final Widget connect;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      return Column(
        children: [send, const SizedBox(height: Space.lg), connect],
      );
    }

    // Both cards share the height of the taller one, so the row closes on a
    // single line. Letting each end at its own content left the send card
    // stopping short of the QR card, and since the window background sits one
    // step from the card fill, that gap became the largest empty shape on
    // screen — a rendering fault, not a composition.
    //
    // The send card is what absorbs the difference: its drop zone grows into
    // the extra height, which is the right way round. A bigger drop target is
    // a better drop target, and it is the card that should dominate the row.
    //
    // IntrinsicHeight is what gives `stretch` a bounded height to work with:
    // this row lives in a scroll view, so its own height is unbounded. The QR
    // card can answer the intrinsic query because its plate is a tight
    // SizedBox; see connect_panel.dart.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: send),
          const SizedBox(width: Space.xl),
          SizedBox(width: 420, child: connect),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.running, required this.narrow});

  final bool running;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    // The wordmark sits beside the logo; the description runs the full width
    // under both, so a narrow window never squeezes it into a thin column.
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/filefly-128.png',
              width: narrow ? 40 : 52,
              height: narrow ? 40 : 52,
              filterQuality: FilterQuality.medium,
            ),
            SizedBox(width: narrow ? Space.md : Space.lg),
            Text(
              'FileFly',
              style: TextStyle(
                fontSize: narrow ? 30 : 36,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        const Text(
          'Archivos entre la PC y el celular. Sin cable ni apps.',
          style: TextStyle(color: AppColors.textMuted, height: 1.45),
        ),
      ],
    );

    final status = _StatusBadge(running: running);

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: Space.md), status],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const SizedBox(width: Space.lg),
        status,
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md - 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flat dot. The label beside it is what states the status; the dot
          // does not need a glow to say it twice.
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: running ? AppColors.accent : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Space.sm + 2),
          Text(running ? 'Activo' : 'Detenido', style: const TextStyle(fontSize: 13)),
        ],
      ),
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
          const Text('No se pudo iniciar FileFly',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: Space.md - 2),
          const Text(
            'Cierra cualquier otra ventana de FileFly: el puerto $_defaultPort debe estar libre.',
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: Space.md - 2),
          SelectableText(message, style: kMonoStyle.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
