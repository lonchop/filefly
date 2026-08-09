import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme.dart';

/// QR code and pairing link — how a phone gets in without installing anything.
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
                  // Stays pure white on purpose: a scanner needs the quiet
                  // zone around the code to be white.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Radii.inset),
                ),
                // The tight box is load-bearing: QrImageView measures itself
                // with a LayoutBuilder, and the row above asks this card for
                // its intrinsic height. A tight height answers that without
                // reaching into the builder, which cannot report one.
                child: SizedBox.square(
                  dimension: 220,
                  child: QrImageView(
                    data: shareUrls.first,
                    size: 220,
                    backgroundColor: Colors.white,
                    // A URL with a 32-char token needs the density; low
                    // correction keeps the modules big enough to scan.
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _copy(context, shareUrls.first),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar enlace'),
            ),
          ],
        ],
      ),
    );
  }

  void _copy(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado')),
    );
  }
}

class _UrlBox extends StatelessWidget {
  const _UrlBox({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    // Fill, no border. This is a value to read and copy, not a control, and
    // giving it the same edge as the card around it was one more rectangle
    // saying nothing.
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Space.sm),
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.inset),
      ),
      child: SelectableText(
        url,
        style: kMonoStyle,
      ),
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
