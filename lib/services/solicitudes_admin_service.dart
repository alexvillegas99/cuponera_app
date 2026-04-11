import 'package:enjoy/services/core/api_client.dart';

/// Servicio para gestión de solicitudes cuponera desde la vista admin.
class SolicitudesAdminService {
  final _api = ApiClient.instance;

  /// Lista solicitudes con paginación y filtro por estado.
  /// Endpoint: GET /solicitudes-cuponera
  Future<Map<String, dynamic>> listar({
    String? estado,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (estado != null && estado.isNotEmpty) params['estado'] = estado;

    final resp = await _api.get('/solicitudes-cuponera', queryParameters: params);
    final data = resp.data;
    if (data is Map<String, dynamic>) return data;
    if (data is List) return {'items': data, 'total': data.length};
    return {'items': [], 'total': 0};
  }

  /// Actualiza el estado de una solicitud (APROBADO / RECHAZADO).
  /// Endpoint: PATCH /solicitudes-cuponera/:id/estado
  Future<void> actualizarEstado(String id, Map<String, dynamic> data) async {
    await _api.patch('/solicitudes-cuponera/$id/estado', data: data);
  }
}
