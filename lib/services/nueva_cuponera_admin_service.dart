import 'package:enjoy/services/core/api_client.dart';

/// Servicio para crear cupones manualmente desde la vista admin.
class NuevaCuponeraAdminService {
  final _api = ApiClient.instance;

  /// Crea un cupón asignado a un cliente.
  /// Endpoint: POST /cupones
  Future<Map<String, dynamic>> crearCupon({
    required String versionId,
    required String clienteId,
    required String usuarioActivadorId,
  }) async {
    final resp = await _api.post('/cupones', data: {
      'version': versionId,
      'cliente': clienteId,
      'usuarioActivador': usuarioActivadorId,
    });
    final data = resp.data;
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  /// Busca versiones activas de cuponera por nombre.
  /// Endpoint: GET /versiones/buscar/nombre?nombre=...&estado=true
  Future<List<Map<String, dynamic>>> buscarVersiones(String nombre) async {
    final params = <String, dynamic>{'estado': 'true'};
    if (nombre.isNotEmpty) params['nombre'] = nombre;
    final resp = await _api.get('/versiones/buscar/nombre', queryParameters: params);
    final data = resp.data;
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }
}
