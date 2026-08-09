import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Zona de soltar más selector de archivos: el lado de escritorio de "mandar un
/// archivo".
class SendPanel extends StatefulWidget {
  const SendPanel({super.key, required this.onFilesChosen, this.fillHeight = false});

  final Future<void> Function(List<String> paths) onFilesChosen;

  /// Se activa cuando la tarjeta va al lado de la tarjeta de conectar, que es
  /// más alta, y tiene una altura acotada hacia la que crecer. Apilada en una
  /// ventana estrecha no hay altura que rellenar, y un `Expanded` no tendría
  /// nada contra lo que resolverse.
  ///
  /// No es el antiguo indicador `fill`: aquel estiraba una caja con borde
  /// dibujada dentro de la tarjeta. Ahora la tarjeta misma es el blanco de
  /// soltar, así que rellenarla es agrandar el blanco.
  final bool fillHeight;

  @override
  State<SendPanel> createState() => _SendPanelState();
}

class _SendPanelState extends State<SendPanel> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    // Sin caja interior: la tarjeta misma es el blanco de soltar. Un
    // rectángulo con borde dentro de otro rectángulo con borde era la
    // repetición más ruidosa de la ventana, y la zona nunca necesitó un canto
    // propio para aceptar archivos: la tarjeta entera acepta el archivo, y el
    // tinte al arrastrar es lo que lo confirma.
    final zone = ConstrainedBox(
      // Suelo para el layout apilado, donde la tarjeta no tiene hermana a la
      // que igualarse. Al lado de la tarjeta de conectar, la zona se queda con
      // la altura que sobre, que es casi toda la tarjeta.
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
