import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:enjoy/ui/enjoy_colors.dart';

/// Construye los `ThemeData` del sistema **Enjoy · Premium Dark + Glow**.
///
/// Tipografía: **Sora** para títulos (`.hi`) e **Inter** para cuerpo, igual que
/// la propuesta. Se cargan vía `google_fonts` (ya en pubspec), sin assets.
class EnjoyTheme {
  EnjoyTheme._();

  static ThemeData dark() => _build(EnjoyColors.dark());
  static ThemeData light() => _build(EnjoyColors.light());

  /// Estilo de título tipográfico (Sora). Úsalo en widgets donde el CSS
  /// aplicaba `.hi`.
  static TextStyle heading({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? height,
    double letterSpacing = -0.01,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Estilo de cuerpo (Inter).
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static ThemeData _build(EnjoyColors ec) {
    final isDark = ec.isDark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: ec.text,
      displayColor: ec.text,
    );

    return base.copyWith(
      brightness: ec.brightness,
      scaffoldBackgroundColor: ec.bgBottom,
      canvasColor: ec.surfaceMid,
      extensions: <ThemeExtension<dynamic>>[ec],
      colorScheme: ColorScheme(
        brightness: ec.brightness,
        primary: ec.orange,
        onPrimary: ec.onAccent,
        secondary: ec.orangeSoft,
        onSecondary: ec.onAccent,
        surface: ec.surfaceMid,
        onSurface: ec.text,
        error: ec.red,
        onError: Colors.white,
        primaryContainer: ec.surfaceTop,
        onPrimaryContainer: ec.text,
        secondaryContainer: ec.glassStrong,
        onSecondaryContainer: ec.orangeSoft,
        outline: ec.stroke,
      ),
      textTheme: textTheme,
      primaryColor: ec.orange,
      dividerColor: ec.stroke,
      iconTheme: IconThemeData(color: ec.text),
      splashColor: ec.orange.withValues(alpha: .10),
      highlightColor: ec.orange.withValues(alpha: .06),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: ec.text),
        titleTextStyle: heading(size: 19, color: ec.text),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: ec.orange),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ec.surfaceTop,
        contentTextStyle: body(color: ec.text),
        actionTextColor: ec.orangeSoft,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ec.surfaceMid,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: ec.surfaceMid,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ec.surfaceTop,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: heading(size: 18, color: ec.text),
        contentTextStyle: body(size: 14, color: ec.textSoft),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ec.glass,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        hintStyle: body(size: 14, color: ec.textMute),
        labelStyle: body(size: 14, color: ec.textSoft),
        prefixIconColor: ec.orangeSoft,
        suffixIconColor: ec.textMute,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: ec.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: ec.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: ec.orange.withValues(alpha: .5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: ec.red.withValues(alpha: .6)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: ec.red, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ec.orange,
          foregroundColor: ec.onAccent,
          elevation: 0,
          textStyle: heading(size: 15, weight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ec.orangeSoft),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ec.text,
          side: BorderSide(color: ec.strokeStrong),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : ec.textMute,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ec.orange : ec.glassStrong,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ec.glass,
        side: BorderSide(color: ec.stroke),
        labelStyle: body(size: 12, weight: FontWeight.w600, color: ec.textSoft),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: DividerThemeData(color: ec.stroke, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: ec.glass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ec.stroke),
        ),
      ),
    );
  }
}
