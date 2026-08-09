import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:filefly/app/palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Luminancia relativa de WCAG 2.1.
double _luminance(Color color) {
  double channel(int value) {
    final c = value / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final argb = color.toARGB32();
  return 0.2126 * channel((argb >> 16) & 0xFF) +
      0.7152 * channel((argb >> 8) & 0xFF) +
      0.0722 * channel(argb & 0xFF);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final indexHtml = File('assets/web/index.html').readAsStringSync();

  group('palette injection', () {
    test('the served page carries the marker and gets it replaced', () {
      expect(indexHtml, contains(paletteTokenMarker));

      final served = withPaletteTokens(indexHtml);
      expect(served, isNot(contains(paletteTokenMarker)));
      expect(served, contains('--accent:#90d8f1'));
    });

    test('injection fails loudly rather than serving an unstyled page', () {
      expect(() => withPaletteTokens('<html></html>'), throwsStateError);
    });

    test('every custom property the page reads is one the palette emits', () {
      // Esta es la guarda contra la deriva que existía antes: dos listas de
      // colores mantenidas a mano, una de las cuales se quedó atrás en
      // silencio.
      final emitted = {
        for (final pair in buildCssTokens().split(';')) pair.split(':').first,
      };

      final used = RegExp(r'var\((--[a-z0-9-]+)\)')
          .allMatches(indexHtml)
          .map((m) => m.group(1)!)
          .toSet();

      // El espaciado, los radios y el movimiento son asuntos de layout de la
      // página, declarados en la propia hoja de estilos, no colores de los que
      // sea dueña la paleta de Dart.
      final layoutOwned = RegExp(r'^--(s\d|r-|motion|ease-)');
      final colours = used.where((name) => !layoutOwned.hasMatch(name));

      expect(colours, everyElement(isIn(emitted)),
          reason: 'la página usa una variable de color que palette.dart no emite');
    });
  });

  group('contrast (WCAG 2.1 AA)', () {
    const onSurfaces = {
      'fondo': AppColors.background,
      'card': AppColors.surface,
      'fila': AppColors.surfaceMuted,
    };

    for (final entry in onSurfaces.entries) {
      test('el texto sobre ${entry.key} llega a 4.5:1', () {
        for (final fg in [AppColors.text, AppColors.textMuted, AppColors.accent, AppColors.danger]) {
          expect(_contrast(fg, entry.value), greaterThanOrEqualTo(4.5));
        }
      });

      test('el borde interactivo sobre ${entry.key} llega a 3:1', () {
        expect(_contrast(AppColors.borderStrong, entry.value), greaterThanOrEqualTo(3.0));
      });
    }

    test('el texto del botón primario llega a 4.5:1 en reposo y en hover', () {
      expect(_contrast(AppColors.accentInk, AppColors.accent), greaterThanOrEqualTo(4.5));
      expect(_contrast(AppColors.accentInk, AppColors.accentStrong), greaterThanOrEqualTo(4.5));
    });
  });

  group('web manifest', () {
    test('declara los iconos que el servidor publica', () {
      final manifest = jsonDecode(buildWebManifest()) as Map<String, dynamic>;
      final sources = [
        for (final icon in manifest['icons'] as List) (icon as Map)['src'] as String,
      ];

      expect(sources, containsAll(['/icon-256.png', '/icon-512.png']));
      expect(manifest['theme_color'], '#080e15');
    });
  });
}
