import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData getAppTheme() => ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF398AE5), // Azul principal del login
          onPrimary: Colors.white, // Texto blanco sobre primario
          secondary: Color(0xFF64B5F6), // Azul claro
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF0D47A1), // Azul profundo para texto
          error: Color(0xFFD32F2F),
          onError: Colors.white,
          primaryContainer: Color(0xFFBBDEFB), // Azul claro variante
          onPrimaryContainer: Color(0xFF0D47A1),
          secondaryContainer: Color(0xFFE3F2FD), // Fondo
          onSecondaryContainer: Color(0xFF0D47A1),
          outline: Color(0xFFB3E5FC), // Bordes azules claros
        ),

        scaffoldBackgroundColor: Color(0xFFE3F2FD), // Fondo general claro

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF398AE5), // Azul fuerte del login
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF398AE5),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),

        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF0D47A1), fontSize: 16),
          bodyMedium: TextStyle(color: Colors.grey[700], fontSize: 14),
          titleLarge: const TextStyle(
            color: Color(0xFF398AE5),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF398AE5),
              width: 2,
            ),
          ),
          labelStyle: TextStyle(color: Colors.grey[800]),
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),

        toggleButtonsTheme: ToggleButtonsThemeData(
          borderColor: const Color(0xFF64B5F6),
          selectedBorderColor: const Color(0xFF398AE5),
          selectedColor: Colors.white,
          fillColor: const Color(0xFF398AE5),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          borderRadius: BorderRadius.circular(20),
        ),
      );
}
