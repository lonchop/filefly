import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme.dart';

/// Código QR y enlace de emparejamiento: por dónde entra un celular sin
/// instalar nada.
class ConnectPanel extends StatelessWidget {
  const ConnectPanel({super.key, required this.shareUrls});

  final List<String> shareUrls;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Conectar el celular', subtitle: 'Ambos en la misma red Wi-Fi.'),
          const SizedBox(height: Space.xl - 4),
          if (shareUrls.isEmpty)
            const _NoNetwork()
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  // Se queda en blanco puro a propósito: un escáner necesita
                  // que la zona de silencio alrededor del código sea blanca.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Radii.inset),
                ),
                // La caja ajustada sostiene el layout: QrImageView se mide con
                // un LayoutBuilder, y la fila de arriba le pide a esta tarjeta
                // su altura intrínseca. Una altura ajustada responde a esa
                // consulta sin entrar en el builder, que no sabe darla.
                child: SizedBox.square(
                  dimension: 220,
                  child: QrImageView(
                    data: shareUrls.first,
                    size: 220,
                    backgroundColor: Colors.white,
                    // Una URL con un token de 32 caracteres necesita la
                    // densidad; una corrección baja mantiene los módulos lo
                    // bastante grandes como para escanearlos.
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('Escanea con la cámara del celular',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            const SizedBox(height: 20),
            for (final url in shareUrls) _UrlBox(url: url),
          ],
          const SizedBox(height: Space.md),
          // La pregunta "¿esto es seguro?" se hace justo aquí, mirando un
          // código que va a abrir la carpeta de la PC en otro aparato. La
          // respuesta va donde se hace la pregunta.
          const Text(
            'Todo viaja por tu red local. Nada sale a internet.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _UrlBox extends StatelessWidget {
  const _UrlBox({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    // Relleno, sin borde. Esto es un valor para leer y copiar, no un control, y
    // darle el mismo canto que la tarjeta que lo rodea era un rectángulo más
    // sin decir nada.
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Space.sm),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.inset),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              url,
              style: kMonoStyle,
            ),
          ),
          const SizedBox(width: Space.sm),
          // La acción vive junto al valor que copia: un botón con etiqueta
          // debajo repetía lo que la caja ya dice.
          IconButton(
            onPressed: () => _copy(context),
            tooltip: 'Copiar enlace',
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: AppColors.textMuted,
            // La caja mide 18px de alto de texto: el objetivo por defecto de
            // 40px la estiraría. 32px sigue siendo cómodo con mouse.
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado')),
    );
  }
}

class _NoNetwork extends StatelessWidget {
  const _NoNetwork();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Esta PC no está en una red local. Conéctala al Wi-Fi y reinicia FileFly.',
        style: TextStyle(color: AppColors.textMuted, height: 1.5),
      ),
    );
  }
}
