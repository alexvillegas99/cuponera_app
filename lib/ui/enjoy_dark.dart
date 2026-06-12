import 'package:flutter/material.dart';

/// Tokens del tema "Premium Dark + Glow" de Enjoy.
/// Se usan para el rediseño visual sin alterar la lógica de cada pantalla.
class ED {
  // Fondos
  static const bg = Color(0xFF0A1322); // fondo principal
  static const bg2 = Color(0xFF0E1B2E); // app bars / superficies
  static const card = Color(0xCC15263F); // tarjeta glass (con opacidad)
  static const cardSolid = Color(0xFF15263F); // tarjeta sólida
  static const field = Color(0x14FFFFFF); // inputs / chips (blanco 8%)
  static const border = Color(0x1AFFFFFF); // bordes (blanco 10%)
  static const borderStrong = Color(0x2EFFFFFF); // bordes (blanco 18%)

  // Texto
  static const text = Color(0xFFF4F7FB); // títulos / texto principal
  static const sub = Color(0xFFA9B6CC); // subtítulos
  static const mute = Color(0xFF7E8DA8); // labels / placeholders

  // Marca / estados
  static const accent = Color(0xFFFF9F1C); // naranja
  static const accentSoft = Color(0xFFFFB54D); // naranja claro
  static const green = Color(0xFF2BD67B);
  static const red = Color(0xFFFF5C73);
  static const blue = Color(0xFF5BA4F0);

  // Gradiente principal de botones / acentos
  static const gradient = LinearGradient(
    colors: [accentSoft, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Glow circular para fondos.
  static Widget glow(double size, Color color) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, const Color(0x00000000)]),
          ),
        ),
      );
}
