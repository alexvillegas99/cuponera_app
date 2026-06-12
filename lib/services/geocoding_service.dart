import 'dart:convert';
import 'package:http/http.dart' as http;

/// Reverse geocoding (coordenadas → dirección de texto) usando **Nominatim
/// (OpenStreetMap)**, la misma fuente que el panel web Angular. Gratuito y sin
/// API key. Devuelve `null` si no se pudo resolver (el usuario igual puede
/// escribir la dirección a mano).
class GeocodingService {
  GeocodingService._();

  static const _base = 'https://nominatim.openstreetmap.org/reverse';

  static Future<String?> reverse(double lat, double lng) async {
    final uri = Uri.parse(
      '$_base?lat=$lat&lon=$lng&format=json&accept-language=es',
    );
    try {
      final resp = await http.get(
        uri,
        headers: const {
          'Accept-Language': 'es',
          // Nominatim exige un User-Agent identificable.
          'User-Agent': 'EnjoyApp/1.0 (info@holdnicconsultors.com)',
        },
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body);
      if (data is! Map) return null;
      final a = (data['address'] as Map?)?.cast<String, dynamic>() ?? {};

      // Mismo armado de partes que el web: calle, número, barrio, ciudad.
      final partes = <String>[
        (a['road'] ?? a['pedestrian'] ?? a['footway'] ?? '').toString(),
        (a['house_number'] ?? '').toString(),
        (a['suburb'] ?? a['neighbourhood'] ?? a['quarter'] ?? '').toString(),
        (a['city'] ?? a['town'] ?? a['village'] ?? a['county'] ?? '').toString(),
      ].where((s) => s.trim().isNotEmpty).toList();

      return partes.isEmpty ? null : partes.join(', ');
    } catch (_) {
      return null;
    }
  }
}
