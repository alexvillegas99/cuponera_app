import 'package:enjoy/services/core/api_client.dart';

class VersionesService {
  /// Lista versiones activas de cuponeras
  static Future<List<Map<String, dynamic>>> listarActivas() async {
    final resp = await ApiClient.instance.get(
      '/versiones/buscar/nombre',
      queryParameters: {'estado': 'true'},
    );

    if (resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    return [];
  }

  /// Caché en memoria del catálogo de versiones activas.
  static List<Map<String, dynamic>>? _activasCache;

  /// Versión paginada + cacheada (endpoint nuevo aditivo). Mismo shape de
  /// salida que listarActivas; cachea en memoria y solo refresca con [force].
  static Future<List<Map<String, dynamic>>> listarActivasPaginado({
    bool force = false,
    int limit = 50,
  }) async {
    if (!force && _activasCache != null) return _activasCache!;
    final resp = await ApiClient.instance.get(
      '/versiones/buscar/paginado',
      queryParameters: {'estado': 'true', 'page': 1, 'limit': limit},
    );
    final body = resp.data;
    final list = (body is Map && body['data'] is List)
        ? body['data'] as List
        : const [];
    final out = list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _activasCache = out;
    return out;
  }

  /// Locales disponibles para una versión (empate por ciudades)
  static Future<List<Map<String, dynamic>>> listarLocales(String versionId) async {
    final resp = await ApiClient.instance.get('/versiones/$versionId/locales');

    if (resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    return [];
  }
}
