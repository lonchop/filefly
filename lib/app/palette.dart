import 'dart:convert';

import 'package:flutter/painting.dart';

/// Marcador que la página servida lleva dentro de su bloque `:root`.
/// [withPaletteTokens] lo cambia por las custom properties reales al arrancar.
const paletteTokenMarker = '/*__FILEFLY_TOKENS__*/';

/// Los colores de FileFly, tomados del logo: un fuselaje azul marino, un avión
/// celeste y una pantalla de tono hielo.
///
/// Este es el único sitio donde vive un valor hexadecimal. La ventana los
/// renderiza a través de [buildTheme], y la página que se sirve a los celulares
/// recibe esos mismos valores inyectados en su bloque `:root` por
/// [withPaletteTokens], de modo que las dos superficies no pueden separarse
/// como se separaron dos listas mantenidas a mano.
///
/// Cada par de primer plano y fondo que usa la interfaz supera WCAG AA (4,5:1
/// para texto, 3:1 para bordes interactivos); ver `test/palette_test.dart`.
abstract final class AppColors {
  /// Fondo de la página. Casi negro, teñido con el azul marino del logo, nunca
  /// negro puro.
  static const background = Color(0xFF080E15);

  /// Fondo de tarjetas y paneles.
  static const surface = Color(0xFF101A24);

  /// Superficies embutidas: filas de archivo, cajas de URL, pista de progreso.
  static const surfaceMuted = Color(0xFF17232F);

  /// Filete que da estructura. Es decorativo, no indica un estado.
  static const border = Color(0xFF223240);

  /// Borde de un control interactivo. Supera 3:1 contra ambas superficies.
  static const borderStrong = Color(0xFF587085);

  /// El avión del logo. El único acento: no hay un segundo.
  static const accent = Color(0xFF90D8F1);

  /// El acento bajo hover y foco.
  static const accentStrong = Color(0xFFB4E6F7);

  /// Texto e iconos dibujados encima de [accent].
  static const accentInk = Color(0xFF072430);

  /// El fuselaje del logo. Carga el significado del acento donde un relleno
  /// gritaría.
  static const accentDeep = Color(0xFF21476C);

  /// El tono de la pantalla del logo, usado para el texto corrido.
  static const text = Color(0xFFE4EFF5);

  static const textMuted = Color(0xFF8FA6B6);

  static const danger = Color(0xFFF09AA6);
}

/// Las custom properties del `:root` que lee la página servida.
///
/// Los nombres los consume `assets/web/index.html`; renombrar uno aquí sin
/// renombrarlo allí deja esa regla cayendo a su valor inicial.
String buildCssTokens() {
  const tokens = <String, Color>{
    '--ink': AppColors.background,
    '--surface': AppColors.surface,
    '--surface-muted': AppColors.surfaceMuted,
    '--border': AppColors.border,
    '--border-strong': AppColors.borderStrong,
    '--accent': AppColors.accent,
    '--accent-strong': AppColors.accentStrong,
    '--accent-ink': AppColors.accentInk,
    '--accent-deep': AppColors.accentDeep,
    '--text': AppColors.text,
    '--text-muted': AppColors.textMuted,
    '--danger': AppColors.danger,
  };

  return [for (final entry in tokens.entries) '${entry.key}:${_hex(entry.value)}'].join(';');
}

/// Devuelve [html] con la paleta escrita dentro de su bloque `:root`.
///
/// Lanza si falta el marcador: una página servida sin sus custom properties se
/// renderiza sin estilos, y fallar al arrancar es mejor que mandarle eso al
/// celular de alguien.
String withPaletteTokens(String html) {
  if (!html.contains(paletteTokenMarker)) {
    throw StateError('assets/web/index.html no contiene $paletteTokenMarker');
  }
  return html.replaceFirst(paletteTokenMarker, buildCssTokens());
}

/// El manifest de aplicación web de la página servida.
///
/// Sin él, "añadir a la pantalla de inicio" guarda una captura de la página
/// como icono, que es lo que mostraba el celular antes de que esto existiera.
/// Las rutas de los iconos las sirve `FileServer.publicAssets`.
String buildWebManifest() => jsonEncode({
      'name': 'FileFly',
      'short_name': 'FileFly',
      'description': 'Transfiere archivos entre tu celular y tu PC por la red local.',
      'start_url': '/',
      'scope': '/',
      'display': 'standalone',
      'background_color': _hex(AppColors.background),
      'theme_color': _hex(AppColors.background),
      'icons': [
        {'src': '/icon-256.png', 'sizes': '256x256', 'type': 'image/png'},
        {'src': '/icon-512.png', 'sizes': '512x512', 'type': 'image/png'},
      ],
    });

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
