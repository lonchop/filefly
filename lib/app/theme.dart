import 'package:flutter/material.dart';

import 'palette.dart';

export 'palette.dart' show AppColors;

/// Below this window width the two top panels stop sitting side by side.
/// Picked from the content: the QR plate plus a readable send panel stop
/// fitting a row somewhere just under 900 logical pixels.
const kNarrowWindow = 900.0;

/// Spacing scale. Every gap and pad in the window comes from here, so the
/// distance inside a group always reads as smaller than the distance between
/// groups.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Corner radii. Containers are softer than the controls inside them.
abstract final class Radii {
  static const control = 10.0;
  static const inset = 12.0;
  static const card = 18.0;
}

/// Duration for every state change in the window. Short enough to feel like
/// feedback rather than animation.
const kMotion = Duration(milliseconds: 140);

/// Inter: a UI face with a tall x-height, so the 12–14px labels this window is
/// mostly made of stay readable, and unambiguous 1/l/I — the window shows IPs
/// and tokens. Bundled rather than left to the platform, so Linux and Windows
/// render the same window.
const kSansFamily = 'Inter';

/// JetBrains Mono for paths, URLs and sizes. Its x-height matches Inter's, so
/// a monospaced path set next to a label doesn't read as smaller.
const kMonoFamily = 'JetBrainsMono';

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.accentInk,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: kSansFamily,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    focusColor: AppColors.accent.withValues(alpha: 0.16),
    hoverColor: AppColors.accent.withValues(alpha: 0.08),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentInk,
        disabledBackgroundColor: AppColors.surfaceMuted,
        disabledForegroundColor: AppColors.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: Space.lg),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return AppColors.accentInk.withValues(alpha: 0.18);
          }
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
            return AppColors.accentInk.withValues(alpha: 0.10);
          }
          return null;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        // The strong border is what identifies this as a control, so it has to
        // clear the 3:1 non-text contrast bar on its own.
        side: const BorderSide(color: AppColors.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: Space.lg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceMuted,
      contentTextStyle: TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.surfaceMuted,
    ),
  );
}

/// The rounded panel every section of the window sits in.
///
/// Elevation here is a hairline border, not a shadow — the window uses one
/// elevation language throughout.
///
/// This is the window's only box. Nesting a second bordered, filled rectangle
/// inside one makes three different things — a drop target, a read-only value,
/// a list row — render identically, and the window stops having a hierarchy.
/// Inner regions separate themselves with a hairline or a fill, never with the
/// full card recipe.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.xl),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Only for a card that carries a state of its own: the send card tints
  /// while files are dragged over it. Everything else takes the defaults so
  /// the window keeps one card treatment.
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kMotion,
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        border: Border.all(color: borderColor ?? AppColors.border),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.subtitle, super.key});

  final String title;

  /// Optional: only when the title alone leaves something unsaid.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: Space.xs + 2),
          Text(subtitle!, style: const TextStyle(color: AppColors.textMuted, height: 1.45)),
        ],
      ],
    );
  }
}

/// Monospace style for paths, URLs and sizes. Tabular figures keep the digits
/// from shifting as a transfer counts up.
const kMonoStyle = TextStyle(
  fontFamily: kMonoFamily,
  fontSize: 12,
  height: 1.5,
  fontFeatures: [FontFeature.tabularFigures()],
);

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}
