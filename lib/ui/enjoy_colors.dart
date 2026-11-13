import 'package:flutter/material.dart';

/// Tokens de color del sistema visual **Enjoy — Azul de marca** (afiche oficial):
///  · Claro  → 60 Blanco · 30 Azul Marino #0A1F5C · 10 Azul Real #1565D8
///  · Oscuro = **Grafito azul** → 60 Carbón azulado #121722 · 30 Grafito #1A2130 · 10 Azul #3D7FF0
/// El rojo queda solo para errores (ya no compite con el acento).
/// `orange`/`orangeSoft` se conservan como nombre del **acento** de cada tema.
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
  /// Plano a propósito (Polar/Tormenta): los degradados de acento se ven
  /// "generados". Se mantiene como gradiente por compatibilidad de API.
  LinearGradient get accentGradient => LinearGradient(
        colors: [orange, orange],
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
  //  Variante OSCURA — Edición Tormenta
  // ===================================================================
  factory EnjoyColors.dark() => const EnjoyColors(
        brightness: Brightness.dark,
        bgTop: Color(0xFF121722), // Carbón azulado
        bgBottom: Color(0xFF0F141E),
        glowOrange: Color(0x00000000), // sin halos
        glowBlue: Color(0x00000000),
        surfaceTop: Color(0xFF1A2130),
        surfaceMid: Color(0xFF171E2C),
        surfaceBottom: Color(0xFF151B28),
        glass: Color(0xFF1A2130), // tarjetas (Grafito)
        glassStrong: Color(0xFF20283A),
        stroke: Color(0xFF2A3346),
        strokeStrong: Color(0xFF364156),
        cardGradTop: Color(0x1A3D7FF0),
        cardGradBottom: Color(0x00FFFFFF),
        orange: Color(0xFF3D7FF0), // Azul (acento; texto blanco encima)
        orangeSoft: Color(0xFF8DB8FF), // acento como TEXTO/ícono legible sobre grafito
        yellow: Color(0xFFF2B33D),
        green: Color(0xFF3DD68C),
        red: Color(0xFFFF6B7A),
        blue: Color(0xFF8FB8FF),
        text: Color(0xFFEEF2F8),
        textSoft: Color(0xFFC3CCDA),
        textMute: Color(0xFF9AA6BC),
        onAccent: Color(0xFFFFFFFF),
        iconGlassTop: Color(0xFF1C2B47), // tinte azul profundo
        iconGlassBottom: Color(0xFF18253D),
      );

  // ===================================================================
  //  Variante CLARA — Edición Polar
  // ===================================================================
  factory EnjoyColors.light() => const EnjoyColors(
        brightness: Brightness.light,
        bgTop: Color(0xFFF4F7FC), // Blanco
        bgBottom: Color(0xFFEDF2FA),
        glowOrange: Color(0x00000000), // sin halos
        glowBlue: Color(0x241565D8), // lavado azul suave
        surfaceTop: Color(0xFFFFFFFF),
        surfaceMid: Color(0xFFF8FAFE),
        surfaceBottom: Color(0xFFF1F5FB),
        glass: Color(0xFFFFFFFF),
        glassStrong: Color(0xFFF4F7FC),
        stroke: Color(0xFFE1E8F4),
        strokeStrong: Color(0xFFC7D5EC),
        cardGradTop: Color(0x0F1565D8),
        cardGradBottom: Color(0x00FFFFFF),
        orange: Color(0xFF1565D8), // Azul Real (acento)
        orangeSoft: Color(0xFF0F56C2), // acento como TEXTO/ícono legible sobre blanco
        yellow: Color(0xFFD99A0B),
        green: Color(0xFF12A060),
        red: Color(0xFFC62839), // error (único rojo de la app)
        blue: Color(0xFF0B6E9E),
        text: Color(0xFF0B1B45), // marino
        textSoft: Color(0xFF3D5277),
        textMute: Color(0xFF5A6E92),
        onAccent: Color(0xFFFFFFFF),
        iconGlassTop: Color(0xFFE8F0FC), // tinte azul
        iconGlassBottom: Color(0xFFDCE8FA),
      );

  // ===================================================================
  //  Tokens derivados (no animados): secundario 30%, navegación, estados
  // ===================================================================

  /// Acento usado como TEXTO (legible sobre la superficie del tema).
  Color get accentText => orangeSoft;

  /// Color secundario (el 30%): Azul Marino en claro, marino profundo en oscuro.
  Color get secondary => isDark ? const Color(0xFF0E1320) : const Color(0xFF0A1F5C);

  /// Tono profundo del secundario (íconos neutros, botones secundarios).
  Color get secondaryDeep => isDark ? const Color(0xFFDCE4F2) : const Color(0xFF0A2A6E);

  /// Tinte del secundario (fondos de chips, cabeceras, activo de navegación).
  Color get secondaryTint => isDark ? const Color(0x14FFFFFF) : const Color(0xFFE8F0FC);

  /// Superficie de navegación (dock, app bars, sheets).
  Color get navSurface => isDark ? const Color(0xFF0E1320) : const Color(0xFFFBFCFF);

  /// Fondo del ítem activo de navegación.
  Color get navActive => isDark ? const Color(0x14FFFFFF) : const Color(0xFFE8F0FC);

  /// Sombra estándar de tarjeta.
  List<BoxShadow> get shadowSm => isDark
      ? const [BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 10), spreadRadius: -12)]
      : const [
          BoxShadow(color: Color(0x0D0B1B45), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x290B1B45), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -12),
        ];

  /// Sombra del CTA principal (acento), discreta.
  /// Sombra del CTA: neutra (sin halo de color), solo para despegarlo.
  List<BoxShadow> get shadowAccent => [
        BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .32 : .14),
            blurRadius: 10,
            offset: const Offset(0, 4)),
      ];

  /// Tonos de estado legibles (texto / fondo / borde).
  EnjoyTone get toneOk => isDark
      ? const EnjoyTone(Color(0xFF7EE2B0), Color(0x243DD68C), Color(0x593DD68C))
      : const EnjoyTone(Color(0xFF0B7A48), Color(0xFFE3F5EC), Color(0xFFBFE6D1));
  EnjoyTone get toneWarn => isDark
      ? const EnjoyTone(Color(0xFFFFD27A), Color(0x24F2B33D), Color(0x61F2B33D))
      : const EnjoyTone(Color(0xFF8A5A00), Color(0xFFFBF0D6), Color(0xFFF0D9A0));
  EnjoyTone get toneDanger => isDark
      ? const EnjoyTone(Color(0xFFFFB3BB), Color(0x29FF5A6A), Color(0x66FF5A6A))
      : const EnjoyTone(Color(0xFFA31D33), Color(0xFFFBE6EA), Color(0xFFF2C2CB));
  EnjoyTone get toneInfo => isDark
      ? const EnjoyTone(Color(0xFFB9D2FF), Color(0x248FB8FF), Color(0x5C8FB8FF))
      : const EnjoyTone(Color(0xFF0B6E9E), Color(0xFFE1F4FD), Color(0xFFB3E3F8));
  EnjoyTone get toneAccent => isDark
      ? const EnjoyTone(Color(0xFF9CC3FF), Color(0x293D7FF0), Color(0x663D7FF0))
      : const EnjoyTone(Color(0xFF0F56C2), Color(0xFFE8F0FC), Color(0xFFC3D7F5));
  EnjoyTone get toneNeutral => isDark
      ? const EnjoyTone(Color(0xFFC3CCDA), Color(0x1FFFFFFF), Color(0x38FFFFFF))
      : const EnjoyTone(Color(0xFF3D5277), Color(0xFFF4F7FC), Color(0xFFDCE6F4));

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

/// Tripleta de color para pills/badges de estado.
@immutable
class EnjoyTone {
  const EnjoyTone(this.fg, this.bg, this.border);
  final Color fg;
  final Color bg;
  final Color border;
}

/// Acceso rápido a los tokens Enjoy desde cualquier `BuildContext`.
extension EnjoyColorsX on BuildContext {
  EnjoyColors get ec =>
      Theme.of(this).extension<EnjoyColors>() ?? EnjoyColors.dark();
}
