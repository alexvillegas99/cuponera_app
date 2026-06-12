// lib/services/comentarios_service.dart
import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';

class ComentariosService {
  static String _kMio(String usuarioId, String clienteId) =>
      'comentarios:mio:$usuarioId:$clienteId';

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
  /// Si 404 -> retorna null. Si hay otro error y tenemos cache, devolvemos
  /// el cache para que la pantalla de detalle del local funcione offline.
  Future<Map<String, dynamic>?> obtenerMiComentario({
    required String usuarioId,
    required String clienteId,
  }) async {
    try {
      final resp = await ApiClient.instance.get(
        '/comentarios/mio/$usuarioId',
        queryParameters: {'clienteId': clienteId},
      );
      final data = resp.data as Map<String, dynamic>;
      await CacheService.I.write(_kMio(usuarioId, clienteId), data);
      return data;
    } catch (e) {
      // 404 = no hay comentario → null. Otros errores → intentar cache.
      if (e.toString().contains('404')) return null;
      final cached = await CacheService.I
          .read<Map<String, dynamic>>(_kMio(usuarioId, clienteId));
      if (cached != null) return cached;
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
