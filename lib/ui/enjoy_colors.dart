import 'package:flutter/material.dart';

/// Tokens de color del sistema visual **Enjoy · Premium Dark + Glow**.
///
/// Se exponen como [ThemeExtension] para poder tener variante oscura y clara
/// y alternarlas con el [ThemeController]. Cualquier widget lee los tokens con
/// `context.ec` (ver extensión al final del archivo).
///
/// Los valores oscuros replican 1:1 la hoja `enjoy.css` de la propuesta visual.
@immutable
class EnjoyColors extends ThemeExtension<EnjoyColors> {
  const EnjoyColors({
    required this.brightness,
    required this.bgTop,
    required this.bgBottom,
    required this.glowOrange,
    required this.glowBlue,
    required this.surfaceTop,
    required this.surfaceMid,
    required this.surfaceBottom,
    required this.glass,
    required this.glassStrong,
    required this.stroke,
    required this.strokeStrong,
    required this.cardGradTop,
    required this.cardGradBottom,
    required this.orange,
    required this.orangeSoft,
    required this.yellow,
    required this.green,
    required this.red,
    required this.blue,
    required this.text,
    required this.textSoft,
    required this.textMute,
    required this.onAccent,
    required this.iconGlassTop,
    required this.iconGlassBottom,
  });

  final Brightness brightness;

  /// Extremos del degradado base del `Scaffold` (fondo de toda la app).
  final Color bgTop;
  final Color bgBottom;

  /// Colores de los halos radiales (glow) sobre el fondo.
  final Color glowOrange;
  final Color glowBlue;

  /// Degradado de superficie de una pantalla / panel (equivalente a `.scr`).
  final Color surfaceTop;
  final Color surfaceMid;
  final Color surfaceBottom;

  /// Vidrio esmerilado (cards, fields, pills neutras).
  final Color glass;
  final Color glassStrong;

  /// Bordes sutiles.
  final Color stroke;
  final Color strokeStrong;

  /// Degradado para tarjetas con acento (header de membresía, etc.).
  final Color cardGradTop;
  final Color cardGradBottom;

  /// Marca y estados.
  final Color orange;
  final Color orangeSoft;
  final Color yellow;
  final Color green;
  final Color red;
  final Color blue;

  /// Texto.
  final Color text;
  final Color textSoft;
  final Color textMute;

  /// Texto/íconos sobre el gradiente naranja (`#1a1206`).
  final Color onAccent;

  /// Caja de ícono "glass" (`.ic-glass`).
  final Color iconGlassTop;
  final Color iconGlassBottom;

  bool get isDark => brightness == Brightness.dark;

  /// Gradiente naranja principal (botones, FAB, pills activas).
  LinearGradient get accentGradient => LinearGradient(
        colors: [orangeSoft, orange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get greenGradient => LinearGradient(
        colors: [green, green.withValues(alpha: .82)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Gradiente de la superficie base del Scaffold.
  LinearGradient get bgGradient => LinearGradient(
        colors: [bgTop, bgBottom],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  /// Gradiente de superficie de pantalla (`.scr`).
  LinearGradient get surfaceGradient => LinearGradient(
        colors: [surfaceTop, surfaceMid, surfaceBottom],
        stops: const [0.0, 0.6, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  LinearGradient get iconGlassGradient => LinearGradient(
        colors: [iconGlassTop, iconGlassBottom],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ===================================================================
  //  Variante OSCURA (la de la propuesta)
  // ===================================================================
  factory EnjoyColors.dark() => const EnjoyColors(
        brightness: Brightness.dark,
        bgTop: Color(0xFF070D18),
        bgBottom: Color(0xFF060C16),
        glowOrange: Color(0x1AFF9F1C), // naranja 10%
        glowBlue: Color(0x1F2B78D6), // azul 12%
        surfaceTop: Color(0xFF0E1B2E),
        surfaceMid: Color(0xFF0A1322),
        surfaceBottom: Color(0xFF080F1C),
        glass: Color(0x17FFFFFF), // blanco ~9% (cards visibles sobre fondo sólido)
        glassStrong: Color(0x26FFFFFF), // blanco ~15%
        stroke: Color(0x24FFFFFF), // blanco ~14% (bordes que definen las cards)
        strokeStrong: Color(0x38FFFFFF), // blanco ~22%
        cardGradTop: Color(0x2BFF9F1C),
        cardGradBottom: Color(0x0AFFFFFF),
        orange: Color(0xFFFF9F1C),
        orangeSoft: Color(0xFFFFB54D),
        yellow: Color(0xFFFFBF46),
        green: Color(0xFF2BD67B),
        red: Color(0xFFFF5C73),
        blue: Color(0xFF5BA4F0),
        text: Color(0xFFF4F7FB),
        textSoft: Color(0xFFB8C4D8), // un poco más claro: subtítulos legibles
        textMute: Color(0xFF93A1BC), // antes #6E7E99 (muy tenue) → más legible
        onAccent: Color(0xFF1A1206),
        iconGlassTop: Color(0xFF27406B),
        iconGlassBottom: Color(0xFF142540),
      );

  // ===================================================================
  //  Variante CLARA (mismo lenguaje, piel luminosa)
  // ===================================================================
  factory EnjoyColors.light() => const EnjoyColors(
        brightness: Brightness.light,
        bgTop: Color(0xFFF4F7FC),
        bgBottom: Color(0xFFEAF0F8),
        glowOrange: Color(0x1FFF9F1C),
        glowBlue: Color(0x142B78D6),
        surfaceTop: Color(0xFFFFFFFF),
        surfaceMid: Color(0xFFF6F9FD),
        surfaceBottom: Color(0xFFEFF3F9),
        glass: Color(0xFFFFFFFF),
        glassStrong: Color(0xFFF1F5FA),
        stroke: Color(0xFFE3E9F1),
        strokeStrong: Color(0xFFD3DCE8),
        cardGradTop: Color(0x24FF9F1C),
        cardGradBottom: Color(0x00FFFFFF),
        orange: Color(0xFFF08800),
        orangeSoft: Color(0xFFFF9F1C),
        yellow: Color(0xFFE0A521),
        green: Color(0xFF12A85C),
        red: Color(0xFFE23A52),
        blue: Color(0xFF2F7BD0),
        text: Color(0xFF18233A),
        textSoft: Color(0xFF51607A),
        textMute: Color(0xFF8694AC),
        onAccent: Color(0xFF3A2600),
        iconGlassTop: Color(0xFFEAF1FB),
        iconGlassBottom: Color(0xFFDDE7F5),
      );

  @override
  EnjoyColors copyWith({
    Brightness? brightness,
    Color? bgTop,
    Color? bgBottom,
    Color? glowOrange,
    Color? glowBlue,
    Color? surfaceTop,
    Color? surfaceMid,
    Color? surfaceBottom,
    Color? glass,
    Color? glassStrong,
    Color? stroke,
    Color? strokeStrong,
    Color? cardGradTop,
    Color? cardGradBottom,
    Color? orange,
    Color? orangeSoft,
    Color? yellow,
    Color? green,
    Color? red,
    Color? blue,
    Color? text,
    Color? textSoft,
    Color? textMute,
    Color? onAccent,
    Color? iconGlassTop,
    Color? iconGlassBottom,
  }) {
    return EnjoyColors(
      brightness: brightness ?? this.brightness,
      bgTop: bgTop ?? this.bgTop,
      bgBottom: bgBottom ?? this.bgBottom,
      glowOrange: glowOrange ?? this.glowOrange,
      glowBlue: glowBlue ?? this.glowBlue,
      surfaceTop: surfaceTop ?? this.surfaceTop,
      surfaceMid: surfaceMid ?? this.surfaceMid,
      surfaceBottom: surfaceBottom ?? this.surfaceBottom,
      glass: glass ?? this.glass,
      glassStrong: glassStrong ?? this.glassStrong,
      stroke: stroke ?? this.stroke,
      strokeStrong: strokeStrong ?? this.strokeStrong,
      cardGradTop: cardGradTop ?? this.cardGradTop,
      cardGradBottom: cardGradBottom ?? this.cardGradBottom,
      orange: orange ?? this.orange,
      orangeSoft: orangeSoft ?? this.orangeSoft,
      yellow: yellow ?? this.yellow,
      green: green ?? this.green,
      red: red ?? this.red,
      blue: blue ?? this.blue,
      text: text ?? this.text,
      textSoft: textSoft ?? this.textSoft,
      textMute: textMute ?? this.textMute,
      onAccent: onAccent ?? this.onAccent,
      iconGlassTop: iconGlassTop ?? this.iconGlassTop,
      iconGlassBottom: iconGlassBottom ?? this.iconGlassBottom,
    );
  }

  @override
  EnjoyColors lerp(ThemeExtension<EnjoyColors>? other, double t) {
    if (other is! EnjoyColors) return this;
    return EnjoyColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bgTop: Color.lerp(bgTop, other.bgTop, t)!,
      bgBottom: Color.lerp(bgBottom, other.bgBottom, t)!,
      glowOrange: Color.lerp(glowOrange, other.glowOrange, t)!,
      glowBlue: Color.lerp(glowBlue, other.glowBlue, t)!,
      surfaceTop: Color.lerp(surfaceTop, other.surfaceTop, t)!,
      surfaceMid: Color.lerp(surfaceMid, other.surfaceMid, t)!,
      surfaceBottom: Color.lerp(surfaceBottom, other.surfaceBottom, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      strokeStrong: Color.lerp(strokeStrong, other.strokeStrong, t)!,
      cardGradTop: Color.lerp(cardGradTop, other.cardGradTop, t)!,
      cardGradBottom: Color.lerp(cardGradBottom, other.cardGradBottom, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      orangeSoft: Color.lerp(orangeSoft, other.orangeSoft, t)!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      green: Color.lerp(green, other.green, t)!,
      red: Color.lerp(red, other.red, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSoft: Color.lerp(textSoft, other.textSoft, t)!,
      textMute: Color.lerp(textMute, other.textMute, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      iconGlassTop: Color.lerp(iconGlassTop, other.iconGlassTop, t)!,
      iconGlassBottom: Color.lerp(iconGlassBottom, other.iconGlassBottom, t)!,
    );
  }
}

/// Acceso rápido a los tokens Enjoy desde cualquier `BuildContext`.
extension EnjoyColorsX on BuildContext {
  EnjoyColors get ec =>
      Theme.of(this).extension<EnjoyColors>() ?? EnjoyColors.dark();
}
