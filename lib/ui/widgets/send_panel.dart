import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Drop zone plus file picker: the desktop side of "send a file".
class SendPanel extends StatefulWidget {
  const SendPanel({super.key, required this.onFilesChosen, this.fillHeight = false});

  final Future<void> Function(List<String> paths) onFilesChosen;

  /// Set when the card sits beside the taller connect card and has a bounded
  /// height to grow into. Stacked in a narrow window there is no height to
  /// fill, and an `Expanded` would have nothing to resolve against.
  ///
  /// This is not the old `fill` flag: that one stretched a bordered box drawn
  /// inside the card. The card itself is the drop target now, so filling it is
  /// growing the target.
  final bool fillHeight;

  @override
  State<SendPanel> createState() => _SendPanelState();
}

class _SendPanelState extends State<SendPanel> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    // No inner box: the card itself is the drop target. A bordered rectangle
    // inside a bordered rectangle was the window's loudest repetition, and the
    // zone never needed its own edge to be droppable — the whole card accepts
    // the file, and the tint on drag is what confirms it.
    final zone = ConstrainedBox(
      // Floor for the stacked layout, where the card has no sibling to match.
      // Beside the connect card the zone takes whatever height is left over,
      // which is most of the card.
      constraints: const BoxConstraints(minHeight: 180),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_upward_rounded,
              size: 40,
              color: _dragging ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(height: Space.md),
            const Text(
              'Suelta los archivos aquí',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: Space.xl - 4),
            FilledButton(
              onPressed: _pickFiles,
              child: const Text('Buscar en la PC'),
            ),
          ],
        ),
      ),
    );

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        widget.onFilesChosen([for (final file in details.files) file.path]);
      },
      child: AppCard(
        color: _dragging ? AppColors.accentDeep : null,
        borderColor: _dragging ? AppColors.accent : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: widget.fillHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            const SectionTitle(
              'Enviar al celular',
              subtitle: 'Arrastra los archivos a esta tarjeta.',
            ),
            const SizedBox(height: Space.xl - 4),
            if (widget.fillHeight) Expanded(child: zone) else zone,
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final files = await openFiles();
    if (files.isEmpty) return;

    await widget.onFilesChosen([for (final file in files) file.path]);
  }
}
