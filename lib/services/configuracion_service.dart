import 'package:enjoy/services/core/api_client.dart';

class ConfiguracionService {
  /// Obtener el valor de una configuración por clave
  static Future<String?> obtenerValor(String clave) async {
    try {
      final resp = await ApiClient.instance.get('/configuracion/$clave');
      if (resp.statusCode == 200) {
        final data = resp.data as Map<String, dynamic>;
        return data['valor'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Obtener todas las configuraciones
  static Future<Map<String, String>> obtenerTodas() async {
    try {
      final resp = await ApiClient.instance.get('/configuracion');
      if (resp.statusCode == 200) {
        final List<dynamic> data = resp.data as List<dynamic>;
        return {
          for (final item in data)
            item['clave'] as String: item['valor'] as String,
        };
      }
    } catch (_) {}
    return {};
  }
}
