import 'package:flutter/material.dart';

import 'palette.dart';

export 'palette.dart' show AppColors;

/// Por debajo de este ancho de ventana los dos paneles de arriba dejan de ir
/// uno al lado del otro. Sale del contenido: la placa del QR más un panel de
/// envío legible dejan de entrar en una fila algo por debajo de los 900 píxeles
/// lógicos.
const kNarrowWindow = 900.0;

/// Escala de espaciado. Cada hueco y cada relleno de la ventana sale de aquí,
/// para que la distancia dentro de un grupo se lea siempre como menor que la
/// distancia entre grupos.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Radios de esquina. Los contenedores son más suaves que los controles que
/// llevan dentro.
abstract final class Radii {
  static const control = 10.0;
  static const inset = 12.0;
  static const card = 18.0;
}

/// Duración de cada cambio de estado de la ventana. Lo bastante corta como para
/// sentirse respuesta y no animación.
const kMotion = Duration(milliseconds: 140);

/// Inter: una tipografía de interfaz con altura de x grande, para que las
/// etiquetas de 12 a 14 px de las que está hecha esta ventana sigan siendo
/// legibles, y con 1/l/I inequívocos, porque la ventana muestra IPs y tokens.
/// Va empaquetada en vez de dejarla a la plataforma, para que Linux y Windows
/// rendericen la misma ventana.
const kSansFamily = 'Inter';

/// JetBrains Mono para rutas, URLs y tamaños. Su altura de x coincide con la de
/// Inter, así que una ruta monoespaciada junto a una etiqueta no se lee más
/// pequeña.
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
        // El borde fuerte es lo que identifica esto como un control, así que
        // tiene que superar por sí solo el listón de 3:1 de contraste no
        // textual.
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

/// El panel redondeado dentro del que va cada sección de la ventana.
///
/// Aquí la elevación es un filete, no una sombra: la ventana usa un solo
/// lenguaje de elevación de principio a fin.
///
/// Esta es la única caja de la ventana. Anidar un segundo rectángulo relleno y
/// con borde dentro de otro hace que tres cosas distintas (una zona de soltar,
/// un valor de solo lectura, una fila de lista) se rendericen igual, y la
/// ventana deja de tener jerarquía. Las regiones interiores se separan con un
/// filete o con un relleno, nunca con la receta completa de la tarjeta.
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

  /// Solo para una tarjeta que lleva un estado propio: la tarjeta de envío se
  /// tiñe mientras se arrastran archivos por encima. Todo lo demás toma los
  /// valores por defecto, para que la ventana mantenga un único tratamiento de
  /// tarjeta.
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

  /// Opcional: solo cuando el título por sí solo deja algo sin decir.
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

/// Estilo monoespaciado para rutas, URLs y tamaños. Las cifras tabulares evitan
/// que los dígitos se muevan mientras una transferencia va contando.
const kMonoStyle = TextStyle(
  fontFamily: kMonoFamily,
  fontSize: 12,
  height: 1.5,
  fontFeatures: [FontFeature.tabularFigures()],
);

const _monthNames = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// La fecha de un archivo en la forma corta que usa la lista.
///
/// La columna existe para separar de un vistazo lo que acaba de llegar de lo
/// que lleva ahí semanas, así que hoy se reduce a la hora y el resto a la
/// fecha. Una marca de tiempo completa en cada fila sería una columna de ruido.
String formatWhen(DateTime moment) {
  final now = DateTime.now();
  final day = DateTime(moment.year, moment.month, moment.day);
  final today = DateTime(now.year, now.month, now.day);
  final elapsed = today.difference(day).inDays;
  final time = '${moment.hour.toString().padLeft(2, '0')}:'
      '${moment.minute.toString().padLeft(2, '0')}';

  if (elapsed == 0) return time;
  if (elapsed == 1) return 'Ayer $time';
  final date = '${moment.day} ${_monthNames[moment.month - 1]}';
  return day.year == today.year ? date : '$date ${moment.year}';
}

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
