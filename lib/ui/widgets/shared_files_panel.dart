import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../server/file_server.dart';

/// The shared folder, as the desktop user sees it.
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

/// Title, folder path and folder controls. The buttons drop under the title
/// once the card is too narrow to hold both without squeezing the path.
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

    // The path doubles as the label and the affordance: it says which folder is
    // shared and opens it, so the card does not need a separate line for each.
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

/// One file in the shared folder.
///
/// Rows separate with a hairline instead of each being its own filled and
/// bordered box. A list of those reads as a stack of cards competing with the
/// panel holding them, and the folder is a list, not a set of cards.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.divided,
    required this.onOpen,
    required this.onDelete,
  });

  final SharedFile file;

  /// Every row but the first draws the rule above it, so the list never opens
  /// or closes on a dangling line.
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
          // A labelled button pair repeated down the list gave a destructive
          // action the same weight as the file name, every row. These stay
          // muted until pointed at; the tooltip carries the label and delete
          // still asks for confirmation.
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

/// Icon-only row control. Muted at rest, its colour on hover, focus and press.
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
      // Carries the accessible name as well as the hover label, so dropping
      // the visible text does not drop the control's meaning.
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
        // The muted-to-colour step is too small to be a focus indicator on its
        // own, and a keyboard user has no pointer to tell them where they are.
        // Focus gets the same weight as press so tabbing through the list is
        // as legible as hovering it.
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
