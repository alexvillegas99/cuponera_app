import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:enjoy/mappers/comercio_mini.dart';

class ComerciosService {
  final String base = dotenv.env['API_URL'] ?? '';

  /// GET /comercios/:usuarioId/detalle-mini
  Future<ComercioMini> obtenerInformacionComercioMini(String usuarioId) async {
    final uri = Uri.parse('$base/usuarios/$usuarioId/detalle-mini');
    print('[ComerciosService] ➡️ GET $uri');

    final resp = await http.get(uri);
    print('[ComerciosService] ⬅️ ${resp.statusCode}');
    print('[ComerciosService] ⬅️ ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('[ComerciosService] ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('[ComerciosService] Esperaba objeto JSON, vino ${decoded.runtimeType}');
    }

    return ComercioMini.fromJson(decoded);
  }
}
