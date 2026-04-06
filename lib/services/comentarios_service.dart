// lib/services/comentarios_service.dart
import 'package:enjoy/services/core/api_client.dart';

class ComentariosService {
  /// GET /comentarios/eligibilidad?usuarioId=...&clienteId=...
  Future<Map<String, dynamic>> elegibilidad({
    required String usuarioId,
    required String clienteId,
  }) async {
    final resp = await ApiClient.instance.get(
      '/comentarios/eligibilidad',
      queryParameters: {'usuarioId': usuarioId, 'clienteId': clienteId},
    );
    if (resp.statusCode != null && resp.statusCode! >= 400) {
      throw Exception('Elegibilidad ${resp.statusCode}: ${resp.data}');
    }
    return resp.data as Map<String, dynamic>;
  }

  /// GET /comentarios/mio/:usuarioId?clienteId=...
  /// Si 404 -> retorna null
  Future<Map<String, dynamic>?> obtenerMiComentario({
    required String usuarioId,
    required String clienteId,
  }) async {
    try {
      final resp = await ApiClient.instance.get(
        '/comentarios/mio/$usuarioId',
        queryParameters: {'clienteId': clienteId},
      );
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      // DioException on 404 -> return null
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  /// PUT /comentarios/mio/:usuarioId
  /// body: { clienteId, calificacion, texto? }
  Future<Map<String, dynamic>> upsertMiComentario({
    required String usuarioId,
    required String clienteId,
    required int calificacion, // 1..5
    String? texto,
  }) async {
    final resp = await ApiClient.instance.put(
      '/comentarios/mio/$usuarioId',
      data: {
        'clienteId': clienteId,
        'calificacion': calificacion,
        'texto': (texto ?? '').trim(),
      },
    );
    if (resp.statusCode != null && resp.statusCode! >= 400) {
      throw Exception('Upsert ${resp.statusCode}: ${resp.data}');
    }
    return resp.data as Map<String, dynamic>;
  }

  /// DELETE /comentarios/mio/:usuarioId?clienteId=...
  Future<void> eliminarMiComentario({
    required String usuarioId,
    required String clienteId,
  }) async {
    await ApiClient.instance.delete('/comentarios/mio/$usuarioId?clienteId=$clienteId');
  }
}
