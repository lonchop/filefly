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
      if (FileSystemEntity.isDirectorySync(path)) continue; // las carpetas no se comparten
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

  /// Le pasa una ruta al entorno de escritorio; no hay API de Dart para esto.
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

    // Se mide sobre la ventana, no sobre la caja de contenido, para que el
    // punto de quiebre signifique lo que dice.
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

/// Enviar y conectar van uno al lado del otro mientras hay sitio, y se apilan
/// en cuanto la ventana se queda demasiado estrecha para que la placa del QR y
/// una zona de soltar legible compartan fila.
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

    // Las dos tarjetas comparten la altura de la más alta, para que la fila
    // cierre en una sola línea. Dejar que cada una terminara en su propio
    // contenido hacía que la tarjeta de envío se quedara corta frente a la del
    // QR y, como el fondo de la ventana está a un paso del relleno de la
    // tarjeta, ese hueco pasaba a ser la forma vacía más grande de la pantalla:
    // parecía un fallo de renderizado, no una composición.
    //
    // La tarjeta de envío es la que absorbe la diferencia: su zona de soltar
    // crece hacia la altura sobrante, que es el sentido correcto. Un blanco de
    // soltar más grande es un blanco mejor, y es la tarjeta que debe dominar la
    // fila.
    //
    // IntrinsicHeight es lo que le da a `stretch` una altura acotada con la que
    // trabajar: esta fila vive dentro de un scroll, así que su propia altura no
    // está acotada. La tarjeta del QR puede responder a la consulta intrínseca
    // porque su placa es un SizedBox ajustado; ver connect_panel.dart.
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
    // El logotipo va al lado de la marca; la descripción ocupa todo el ancho
    // por debajo de los dos, para que una ventana estrecha nunca la exprima
    // hasta dejarla en una columna fina.
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
          // Punto plano. La etiqueta que tiene al lado es la que enuncia el
          // estado; el punto no necesita un halo para decirlo dos veces.
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: running ? AppColors.accent : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Space.sm + 2),
          // Las mismas dos etiquetas que la página del celular. Que cada
          // superficie llamara al mismo estado de forma distinta obligaba a
          // traducir entre pantalla y pantalla.
          Text(running ? 'Conectado' : 'Sin conexión', style: const TextStyle(fontSize: 13)),
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
