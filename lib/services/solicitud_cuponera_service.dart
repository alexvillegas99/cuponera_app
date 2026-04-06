import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SolicitudCuponeraService {
  static final String _base = '${dotenv.env['API_URL'] ?? ''}/solicitudes-cuponera';

  static Future<bool> enviar(Map<String, dynamic> dto) async {
    try {
      final response = await http.post(
        Uri.parse(_base),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(dto),
      );
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> misSolicitudes(String clienteId) async {
    try {
      final response = await http.get(Uri.parse('$_base/cliente/$clienteId'));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (_) {}
    return [];
  }
}
