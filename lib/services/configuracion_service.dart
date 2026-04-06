import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ConfiguracionService {
  static final String _base = '${dotenv.env['API_URL'] ?? ''}/configuracion';

  /// Obtener el valor de una configuración por clave
  static Future<String?> obtenerValor(String clave) async {
    try {
      final response = await http.get(Uri.parse('$_base/$clave'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['valor'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Obtener todas las configuraciones
  static Future<Map<String, String>> obtenerTodas() async {
    try {
      final response = await http.get(Uri.parse(_base));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return {
          for (final item in data)
            item['clave'] as String: item['valor'] as String,
        };
      }
    } catch (_) {}
    return {};
  }
}
