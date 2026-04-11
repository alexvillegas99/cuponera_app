import 'package:enjoy/services/core/api_client.dart';

/// Servicio para búsqueda de clientes desde la vista admin.
class ClientesAdminService {
  final _api = ApiClient.instance;

  /// Busca clientes por nombre, email o cédula.
  /// Endpoint: GET /clientes?q=...
  Future<List<Map<String, dynamic>>> buscar(String q) async {
    final resp = await _api.get('/clientes', queryParameters: {'q': q, 'limit': 20});
    final data = resp.data;
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map) {
      final inner = data['data'] ?? data['items'] ?? data['clientes'];
      if (inner is List) return List<Map<String, dynamic>>.from(inner);
    }
    return [];
  }
}
