import 'package:flutter/material.dart';
import 'package:enjoy/ui/palette.dart';

class AppTheme {
  static ThemeData getAppTheme() => ThemeData(
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: Palette.kPrimary,
      onPrimary: Colors.white,
      secondary: Palette.kAccent,
      onSecondary: Colors.white,
      surface: Palette.kSurface,
      onSurface: Palette.kTitle,
      error: Color(0xFFD32F2F),
      onError: Colors.white,
      primaryContainer: Color(0xFFE8EDF4),
      onPrimaryContainer: Palette.kPrimary,
      secondaryContainer: Color(0xFFFFF4E5),
      onSecondaryContainer: Palette.kAccent,
      outline: Palette.kBorder,
    ),

    scaffoldBackgroundColor: Palette.kBg,

    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.kPrimary,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Roboto',
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Palette.kAccent,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Roboto'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Palette.kTitle, fontSize: 16),
      bodyMedium: TextStyle(color: Palette.kMuted, fontSize: 14),
      titleLarge: TextStyle(
        color: Palette.kTitle,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.kAccent, width: 2),
      ),
      labelStyle: const TextStyle(color: Palette.kMuted),
      hintStyle: const TextStyle(color: Palette.kMuted),
    ),

    toggleButtonsTheme: ToggleButtonsThemeData(
      borderColor: Palette.kBorder,
      selectedBorderColor: Palette.kAccent,
      selectedColor: Colors.white,
      fillColor: Palette.kAccent,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      borderRadius: BorderRadius.circular(20),
    ),
  );
}
