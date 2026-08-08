import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Drop zone plus file picker: the desktop side of "send a file".
class SendPanel extends StatefulWidget {
  const SendPanel({super.key, required this.onFilesChosen});

  final Future<void> Function(List<String> paths) onFilesChosen;

  @override
  State<SendPanel> createState() => _SendPanelState();
}

class _SendPanelState extends State<SendPanel> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Enviar archivos',
            'Elige uno o varios archivos. Quedan disponibles para el celular.',
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 380,
            child: DropTarget(
              onDragEntered: (_) => setState(() => _dragging = true),
              onDragExited: (_) => setState(() => _dragging = false),
              onDragDone: (details) {
                setState(() => _dragging = false);
                widget.onFilesChosen([for (final file in details.files) file.path]);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _dragging ? AppColors.surfaceMuted : Colors.transparent,
                  border: Border.all(
                    color: _dragging ? AppColors.accent : AppColors.border,
                    width: _dragging ? 2 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 44, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'Suelta los archivos aqui',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text('o seleccionalos manualmente',
                        style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _pickFiles,
                      child: const Text('Seleccionar archivos'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) return;

    final paths = [
      for (final file in result.files)
        if (file.path != null) file.path!,
    ];
    if (paths.isNotEmpty) await widget.onFilesChosen(paths);
  }
}
