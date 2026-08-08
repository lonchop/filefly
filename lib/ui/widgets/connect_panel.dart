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
          const SectionTitle(
            'Conectar otro dispositivo',
            'Ambos dispositivos deben estar conectados al mismo router o red Wi-Fi.',
          ),
          const SizedBox(height: 20),
          if (shareUrls.isEmpty)
            const _NoNetwork()
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
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
            const SizedBox(height: 12),
            const Center(
              child: Text('Escanea para abrir FileFly',
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
      const SnackBar(content: Text('Enlace copiado.')),
    );
  }
}

class _UrlBox extends StatelessWidget {
  const _UrlBox({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SelectableText(
        url,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5),
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
        'No se detecto una direccion de red local. Conecta esta PC al Wi-Fi '
        'o a la red del router para poder generar el codigo QR.',
        style: TextStyle(color: AppColors.textMuted, height: 1.5),
      ),
    );
  }
}
