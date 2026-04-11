import 'package:enjoy/services/core/api_client.dart';

/// Servicio para gestión de usuarios desde la vista empresa.
/// Usa ApiClient (Dio) con interceptor de auth automático.
class UsuariosEmpresaService {
  final _api = ApiClient.instance;

  /// Lista todos los usuarios — solo para admin.
  /// Endpoint: GET /usuarios/admin-list
  Future<List<Map<String, dynamic>>> listarAdmin({
    String? q,
    String? rol,
    int limit = 100,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (rol != null && rol.isNotEmpty) params['rol'] = rol;

    final resp = await _api.get('/usuarios/admin-list', queryParameters: params);
    return _parseList(resp.data);
  }

  /// Lista empleados del local — para admin-local.
  /// Endpoint: GET /usuarios/users-local/:localId
  Future<List<Map<String, dynamic>>> listarPorLocal(String localId) async {
    final resp = await _api.get('/usuarios/users-local/$localId');
    return _parseList(resp.data);
  }

  /// Obtiene un usuario por ID.
  Future<Map<String, dynamic>?> obtener(String id) async {
    final resp = await _api.get('/usuarios/$id');
    final data = resp.data;
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  /// Actualiza un usuario. Endpoint: PATCH /usuarios/:id
  Future<void> actualizar(String id, Map<String, dynamic> data) async {
    await _api.patch('/usuarios/$id', data: data);
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map) {
      final inner = data['items'] ?? data['data'] ?? data['usuarios'];
      if (inner is List) return List<Map<String, dynamic>>.from(inner);
    }
    return [];
  }
}
