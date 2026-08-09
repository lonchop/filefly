import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../server/file_server.dart';

/// La carpeta compartida, tal como la ve el usuario de escritorio.
class SharedFilesPanel extends StatelessWidget {
  const SharedFilesPanel({
    super.key,
    required this.narrow,
    required this.files,
    required this.folderPath,
    required this.onRefresh,
    required this.onOpenFolder,
    required this.onChangeFolder,
    required this.onOpenFile,
    required this.onDeleteFile,
  });

  final bool narrow;
  final List<SharedFile> files;
  final String folderPath;
  final VoidCallback onRefresh;
  final VoidCallback onOpenFolder;
  final VoidCallback onChangeFolder;
  final void Function(SharedFile file) onOpenFile;
  final void Function(SharedFile file) onDeleteFile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Head(
            narrow: narrow,
            folderPath: folderPath,
            onOpenFolder: onOpenFolder,
            onChangeFolder: onChangeFolder,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: Space.lg),
          if (files.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Space.xl),
              child: Center(
                child: Text(
                  'Todavía no hay archivos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.45),
                ),
              ),
            )
          else
            for (final (index, file) in files.indexed)
              _FileRow(
                file: file,
                divided: index > 0,
                onOpen: () => onOpenFile(file),
                onDelete: () => onDeleteFile(file),
              ),
        ],
      ),
    );
  }
}

/// Título, ruta de la carpeta y controles de la carpeta. Los botones caen
/// debajo del título en cuanto la tarjeta se queda demasiado estrecha para
/// sostener ambas cosas sin exprimir la ruta.
class _Head extends StatelessWidget {
  const _Head({
    required this.narrow,
    required this.folderPath,
    required this.onOpenFolder,
    required this.onChangeFolder,
    required this.onRefresh,
  });

  final bool narrow;
  final String folderPath;
  final VoidCallback onOpenFolder;
  final VoidCallback onChangeFolder;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      OutlinedButton.icon(
        onPressed: onChangeFolder,
        icon: const Icon(Icons.folder_open_rounded, size: 18),
        label: const Text('Cambiar carpeta'),
      ),
      OutlinedButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Actualizar'),
      ),
    ];

    // La ruta hace de etiqueta y de control a la vez: dice qué carpeta está
    // compartida y la abre, así que la tarjeta no necesita una línea para cada
    // cosa.
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionTitle('Compartidos'),
        const SizedBox(height: Space.xs + 2),
        Tooltip(
          message: 'Abrir en el explorador de archivos',
          child: InkWell(
            onTap: onOpenFolder,
            borderRadius: BorderRadius.circular(Radii.control),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_outlined, size: 15, color: AppColors.textMuted),
                const SizedBox(width: Space.sm),
                Flexible(
                  child: Text(
                    folderPath,
                    style: kMonoStyle.copyWith(color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: Space.md),
          Wrap(spacing: Space.sm, runSpacing: Space.sm, children: buttons),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: title),
        const SizedBox(width: Space.lg),
        buttons[0],
        const SizedBox(width: Space.sm),
        buttons[1],
      ],
    );
  }
}

/// Un archivo de la carpeta compartida.
///
/// Las filas se separan con un filete en vez de ser cada una su propia caja
/// rellena y con borde. Una lista de esas se lee como una pila de tarjetas que
/// compite con el panel que las sostiene, y la carpeta es una lista, no un
/// conjunto de tarjetas.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.divided,
    required this.onOpen,
    required this.onDelete,
  });

  final SharedFile file;

  /// Todas las filas menos la primera dibujan la línea por encima, para que la
  /// lista nunca abra ni cierre con una raya suelta.
  final bool divided;

  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      decoration: divided
          ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border)))
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatBytes(file.size),
                  style: kMonoStyle.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.lg),
          // Un par de botones con etiqueta repetido a lo largo de la lista le
          // daba a una acción destructiva el mismo peso que al nombre del
          // archivo, en cada fila. Estos se quedan apagados hasta que se les
          // apunta; el tooltip lleva la etiqueta y eliminar sigue pidiendo
          // confirmación.
          _RowAction(icon: Icons.open_in_new_rounded, tooltip: 'Abrir', onPressed: onOpen),
          _RowAction(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Eliminar',
            onPressed: onDelete,
            activeColor: AppColors.danger,
          ),
        ],
      ),
    );
  }
}

/// Control de fila solo con icono. Apagado en reposo, con su color al pasar por
/// encima, al recibir el foco y al pulsarlo.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.activeColor = AppColors.accent,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      // Lleva el nombre accesible además de la etiqueta al pasar por encima,
      // para que quitar el texto visible no se lleve por delante el
      // significado del control.
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)) {
            return activeColor;
          }
          return AppColors.textMuted;
        }),
        // El salto de apagado a color es demasiado pequeño para ser por sí solo
        // un indicador de foco, y quien usa el teclado no tiene puntero que le
        // diga dónde está. El foco recibe el mismo peso que la pulsación, para
        // que recorrer la lista con el tabulador sea tan legible como
        // recorrerla con el mouse.
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
            return activeColor.withValues(alpha: 0.22);
          }
          if (states.contains(WidgetState.hovered)) {
            return activeColor.withValues(alpha: 0.10);
          }
          return null;
        }),
      ),
    );
  }
}
