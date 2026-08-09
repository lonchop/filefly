import 'dart:convert';

import 'package:flutter/painting.dart';

/// Marker the served page carries inside its `:root` block. [withPaletteTokens]
/// swaps it for the real custom properties at startup.
const paletteTokenMarker = '/*__FILEFLY_TOKENS__*/';

/// FileFly's colors, sampled from the logo: a navy hull, a sky-blue plane and
/// an ice-toned screen.
///
/// This is the only place a hex value lives. The window renders these through
/// [buildTheme], and the page served to phones has the same values injected
/// into its `:root` block by [withPaletteTokens] — so the two surfaces cannot
/// drift apart the way two hand-kept lists did.
///
/// Every foreground/background pair used by the UI clears WCAG AA (4.5:1 for
/// text, 3:1 for interactive borders); see `test/palette_test.dart`.
abstract final class AppColors {
  /// Page background. Off-black tinted with the logo's navy, never pure black.
  static const background = Color(0xFF080E15);

  /// Card and panel background.
  static const surface = Color(0xFF101A24);

  /// Inset surfaces: file rows, URL boxes, progress track.
  static const surfaceMuted = Color(0xFF17232F);

  /// Hairline that gives structure. Decorative — not a state indicator.
  static const border = Color(0xFF223240);

  /// Border of an interactive control. Clears 3:1 against both surfaces.
  static const borderStrong = Color(0xFF587085);

  /// The plane in the logo. The single accent — there is no second one.
  static const accent = Color(0xFF90D8F1);

  /// Accent under hover and focus.
  static const accentStrong = Color(0xFFB4E6F7);

  /// Text and icons drawn on top of [accent].
  static const accentInk = Color(0xFF072430);

  /// The hull in the logo. Carries accent meaning where a fill would shout.
  static const accentDeep = Color(0xFF21476C);

  /// The logo's screen tone, used for body text.
  static const text = Color(0xFFE4EFF5);

  static const textMuted = Color(0xFF8FA6B6);

  static const danger = Color(0xFFF09AA6);
}

/// The `:root` custom properties the served page reads.
///
/// Names are consumed by `assets/web/index.html`; renaming one here without
/// renaming it there leaves that rule falling back to its initial value.
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

/// Returns [html] with the palette written into its `:root` block.
///
/// Throws if the marker is missing: a page served without its custom
/// properties renders unstyled, and failing at startup beats shipping that to
/// someone's phone.
String withPaletteTokens(String html) {
  if (!html.contains(paletteTokenMarker)) {
    throw StateError('assets/web/index.html no contiene $paletteTokenMarker');
  }
  return html.replaceFirst(paletteTokenMarker, buildCssTokens());
}

/// Web app manifest for the served page.
///
/// Without it, "add to home screen" saves a screenshot of the page as the icon
/// — which is what the phone showed before this existed. The icon paths are
/// served by `FileServer.publicAssets`.
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
