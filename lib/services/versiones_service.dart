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

  /// Locales disponibles para una versión (empate por ciudades)
  static Future<List<Map<String, dynamic>>> listarLocales(String versionId) async {
    final resp = await ApiClient.instance.get('/versiones/$versionId/locales');

    if (resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    return [];
  }
}
