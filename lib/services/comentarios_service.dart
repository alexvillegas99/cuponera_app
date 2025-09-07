// lib/services/comentarios_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ComentariosService {
  final String base = dotenv.env['API_URL'] ?? '';

  /// GET /comentarios/eligibilidad?usuarioId=...&clienteId=...
  Future<Map<String, dynamic>> elegibilidad({
    required String usuarioId,
    required String clienteId,
  }) async {
    final uri = Uri.parse('$base/comentarios/eligibilidad'
        '?usuarioId=$usuarioId&clienteId=$clienteId');
    final resp = await http.get(uri);
    if (resp.statusCode >= 400) {
      throw Exception('Elegibilidad ${resp.statusCode}: ${resp.body}');
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  /// GET /comentarios/mio/:usuarioId?clienteId=...
  /// Si 404 -> retorna null
  Future<Map<String, dynamic>?> obtenerMiComentario({
    required String usuarioId,
    required String clienteId,
  }) async {
    final uri = Uri.parse('$base/comentarios/mio/$usuarioId?clienteId=$clienteId');
    final resp = await http.get(uri);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode >= 400) {
      throw Exception('Mi comentario ${resp.statusCode}: ${resp.body}');
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  /// PUT /comentarios/mio/:usuarioId
  /// body: { clienteId, calificacion, texto? }
  Future<Map<String, dynamic>> upsertMiComentario({
    required String usuarioId,
    required String clienteId,
    required int calificacion, // 1..5
    String? texto,
  }) async {
    final uri = Uri.parse('$base/comentarios/mio/$usuarioId');
    final resp = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'clienteId': clienteId,
        'calificacion': calificacion,
        'texto': (texto ?? '').trim(),
      }),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Upsert ${resp.statusCode}: ${resp.body}');
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  /// DELETE /comentarios/mio/:usuarioId?clienteId=...
  Future<void> eliminarMiComentario({
    required String usuarioId,
    required String clienteId,
  }) async {
    final uri = Uri.parse('$base/comentarios/mio/$usuarioId?clienteId=$clienteId');
    final resp = await http.delete(uri);
    if (resp.statusCode >= 400) {
      throw Exception('Eliminar ${resp.statusCode}: ${resp.body}');
    }
  }
}
