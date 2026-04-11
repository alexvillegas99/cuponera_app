import 'package:enjoy/services/core/api_client.dart';

/// Servicio para gestión de establecimientos desde la vista empresa/admin.
/// Endpoint: GET /usuarios/establecimientos  → { items: [], total, page, pages }
class EstablecimientosEmpresaService {
  final _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> listar({int limit = 100}) async {
    final resp = await _api.get(
      '/usuarios/establecimientos',
      queryParameters: {'limit': limit},
    );
    return _parseList(resp.data);
  }

  Future<Map<String, dynamic>?> obtener(String id) async {
    final resp = await _api.get('/usuarios/$id');
    final data = resp.data;
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  /// Actualiza un establecimiento. Endpoint: PATCH /usuarios/:id
  Future<void> actualizar(String id, Map<String, dynamic> data) async {
    await _api.patch('/usuarios/$id', data: data);
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map) {
      // Respuesta paginada: { items: [], page, total, pages }
      final inner = data['items'] ?? data['data'] ?? data['establecimientos'];
      if (inner is List) return List<Map<String, dynamic>>.from(inner);
    }
    return [];
  }
}
