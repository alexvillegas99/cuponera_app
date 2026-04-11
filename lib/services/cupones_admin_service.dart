import 'package:enjoy/services/core/api_client.dart';

/// Servicio para listar todos los cupones asignados — vista admin.
class CuponesAdminService {
  final _api = ApiClient.instance;

  /// Lista todos los cupones con paginación y búsqueda.
  /// Endpoint: GET /cupones?page=&limit=&search=
  Future<Map<String, dynamic>> listar({
    String search = '',
    int page = 1,
    int limit = 15,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (search.isNotEmpty) params['search'] = search;

    final resp = await _api.get('/cupones', queryParameters: params);
    final data = resp.data;

    if (data is Map<String, dynamic>) return data;
    if (data is List) return {'data': data, 'total': data.length};
    return {'data': [], 'total': 0};
  }
}
