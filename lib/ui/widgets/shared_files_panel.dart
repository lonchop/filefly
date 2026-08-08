import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../server/file_server.dart';

/// The shared folder, as the desktop user sees it.
class SharedFilesPanel extends StatelessWidget {
  const SharedFilesPanel({
    super.key,
    required this.files,
    required this.folderPath,
    required this.onRefresh,
    required this.onOpenFolder,
    required this.onChangeFolder,
    required this.onOpenFile,
    required this.onDeleteFile,
  });

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: SectionTitle(
                  'Compartidos',
                  'Los archivos de esta lista estan disponibles para los dispositivos conectados.',
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: onChangeFolder,
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Cambiar carpeta'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onOpenFolder,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                folderPath,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (files.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text('Aun no hay archivos compartidos.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            for (final file in files) _FileRow(
              file: file,
              onOpen: () => onOpenFile(file),
              onDelete: () => onDeleteFile(file),
            ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onOpen, required this.onDelete});

  final SharedFile file;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(formatBytes(file.size),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          FilledButton(onPressed: onOpen, child: const Text('Abrir')),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
