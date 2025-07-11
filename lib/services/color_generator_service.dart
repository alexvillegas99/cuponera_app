import 'dart:math';
import 'package:flutter/material.dart';

class ColorGeneratorService {
  final List<Color> _baseColors = [
    const Color(0xFF398AE5), // Azul principal
    const Color(0xFF64B5F6), // Azul medio
    const Color(0xFF81C784), // Verde suave
    const Color(0xFFFFB74D), // Naranja suave
    const Color(0xFFE57373), // Rojo claro
    const Color(0xFFBBDEFB), // Celeste claro
    const Color(0xFF0D47A1), // Azul oscuro
  ];

  /// Retorna una lista de [length] colores únicos (usando la base + variaciones).
  List<Color> generateColors(int length) {
    final List<Color> result = [];

    for (int i = 0; i < length; i++) {
      final base = _baseColors[i % _baseColors.length];
      final variation = _generateVariation(base, i ~/ _baseColors.length);
      result.add(variation);
    }

    return result;
  }

  /// Genera una variación basada en el índice
  Color _generateVariation(Color base, int shiftLevel) {
    final hsl = HSLColor.fromColor(base);

    // Rotamos el tono y ajustamos saturación/luminosidad suavemente
    final hue = (hsl.hue + (shiftLevel * 15)) % 360;
    final saturation = (hsl.saturation * (0.95 - shiftLevel * 0.05)).clamp(0.4, 1.0);
    final lightness = (hsl.lightness * (1.0 - shiftLevel * 0.03)).clamp(0.3, 0.85);

    return hsl.withHue(hue).withSaturation(saturation).withLightness(lightness).toColor();
  }
}
