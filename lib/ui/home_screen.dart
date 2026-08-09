import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../server/app_paths.dart';
import '../server/file_server.dart';
import 'widgets/connect_panel.dart';
import 'widgets/files_browser.dart';

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
  bool _dragging = false;

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

  /// Corta o levanta el servidor desde la insignia de estado.
  ///
  /// El token no rota al reiniciar, así que el QR impreso y los celulares ya
  /// emparejados siguen valiendo cuando se vuelve a conectar. Por eso esto no
  /// pide confirmación: es reversible con el mismo clic.
  Future<void> _toggleServer() async {
    final server = _server;
    if (server == null) return;
    if (server.isRunning) {
      await server.stop();
    } else {
      await server.start(port: _defaultPort);
    }
    if (mounted) setState(() {});
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

  Future<void> _pickFiles() async {
    final files = await openFiles();
    if (files.isEmpty) return;

    await _addFiles([for (final file in files) file.path]);
  }

  Future<void> _changeFolder() async {
    final server = _server;
    if (server == null) return;

    final picked = await getDirectoryPath(confirmButtonText: 'Compartir');
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

  Future<void> _deleteFiles(List<SharedFile> files) async {
    if (files.isEmpty) return;

    final what = files.length == 1
        ? 'Se borra "${files.first.name}".'
        : 'Se borran ${files.length} archivos.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(files.length == 1 ? 'Eliminar archivo' : 'Eliminar archivos'),
        content: Text('$what No se puede deshacer.'),
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

    for (final file in files) {
      await _server?.deleteFile(file.path);
    }
    await _refresh();
  }

  /// El QR vive en un diálogo, no en la ventana.
  ///
  /// Emparejar es algo que se hace una vez por celular; la carpeta compartida
  /// es lo que se mira todos los días. Mientras el código ocupó media pantalla,
  /// la lista de archivos empezaba por debajo del pliegue.
  void _showConnect() {
    final server = _server;
    if (server == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: ConnectPanel(shareUrls: server.shareUrls),
          ),
        ),
      ),
    );
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

            // La ventana entera acepta archivos. La zona de soltar dejó de ser
            // una tarjeta con su propio canto: un blanco del tamaño de la
            // ventana es mejor blanco que un rectángulo dentro de ella, y así
            // no le roba sitio a la lista.
            return DropTarget(
              onDragEntered: (_) => setState(() => _dragging = true),
              onDragExited: (_) => setState(() => _dragging = false),
              onDragDone: (details) {
                setState(() => _dragging = false);
                unawaited(_addFiles([for (final file in details.files) file.path]));
              },
              child: AnimatedContainer(
                duration: kMotion,
                color: _dragging ? AppColors.accentDeep : AppColors.background,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Padding(
                      padding: EdgeInsets.all(narrow ? Space.lg : Space.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(
                            narrow: narrow,
                            running: server?.isRunning ?? false,
                            onConnect: server == null || !server.isRunning ? null : _showConnect,
                            onToggle: server == null ? null : _toggleServer,
                          ),
                          SizedBox(height: narrow ? Space.lg : Space.xl),
                          Expanded(
                            child: _startupError != null
                                ? Align(
                                    alignment: Alignment.topCenter,
                                    child: _ErrorCard(message: _startupError!),
                                  )
                                : server == null
                                    ? const Center(child: CircularProgressIndicator())
                                    : FilesBrowser(
                                        narrow: narrow,
                                        files: _files,
                                        folderPath: server.sharedDirectory.path,
                                        onSend: _pickFiles,
                                        onRefresh: _refresh,
                                        onOpenFolder: () =>
                                            _openInDesktop(server.sharedDirectory.path),
                                        onChangeFolder: _changeFolder,
                                        onOpenFile: (file) => _openInDesktop(file.path),
                                        onDeleteFiles: _deleteFiles,
                                      ),
                          ),
                        ],
                      ),
                    ),
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

/// Marca, estado del servidor y la puerta al emparejamiento. Una sola fila:
/// todo lo que no sea la carpeta compartida cabe aquí.
class _Header extends StatelessWidget {
  const _Header({
    required this.narrow,
    required this.running,
    required this.onConnect,
    required this.onToggle,
  });

  final bool narrow;
  final bool running;
  final VoidCallback? onConnect;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icons/filefly-128.png',
          width: narrow ? 34 : 40,
          height: narrow ? 34 : 40,
          filterQuality: FilterQuality.medium,
        ),
        SizedBox(width: narrow ? Space.sm : Space.md),
        Text(
          'FileFly',
          style: TextStyle(
            fontSize: narrow ? 24 : 28,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );

    // En una ventana estrecha el botón se queda sin etiqueta, no la insignia
    // sin sitio: si el servidor se cayó, eso no se puede deducir de ninguna
    // otra cosa en pantalla, mientras que un código QR se reconoce solo.
    final connect = narrow
        ? IconButton.filled(
            onPressed: onConnect,
            tooltip: 'Conectar el celular',
            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.accentInk,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.control),
              ),
            ),
          )
        : FilledButton.icon(
            onPressed: onConnect,
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text('Conectar el celular'),
          );

    return Row(
      children: [
        brand,
        const Spacer(),
        _StatusBadge(running: running, onToggle: onToggle),
        const SizedBox(width: Space.sm),
        connect,
      ],
    );
  }
}

/// La insignia de estado es además el interruptor del servidor.
///
/// El control que dice si algo está encendido es el sitio natural para
/// apagarlo, y así el encabezado no gana un tercer botón al lado del de
/// emparejar. La etiqueta ya nombra el estado; el tooltip nombra la acción.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.running, required this.onToggle});

  final bool running;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: running ? 'Cortar la conexión' : 'Volver a conectar',
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onToggle,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md - 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Punto plano. La etiqueta que tiene al lado es la que enuncia
                // el estado; el punto no necesita un halo para decirlo dos
                // veces.
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
                // superficie llamara al mismo estado de forma distinta obligaba
                // a traducir entre pantalla y pantalla.
                Text(
                  running ? 'Conectado' : 'Sin conexión',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
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
        mainAxisSize: MainAxisSize.min,
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
