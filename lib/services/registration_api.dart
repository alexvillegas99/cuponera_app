// lib/services/registration_api.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class RegistrationApi {
  final String baseUrl = dotenv.env['API_URL'] ?? '';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Crea un cliente (POST /clientes)
  Future<Map<String, dynamic>> crearCliente(Map<String, dynamic> dto) async {
    final uri = Uri.parse('$baseUrl/clientes');
    final resp = await http.post(uri, headers: _headers, body: jsonEncode(dto));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Error ${resp.statusCode}: ${resp.body}');
  }

  /// Envía solicitud de empresa (ajusta la ruta a la tuya si es distinta)
  Future<void> enviarSolicitudEmpresa(Map<String, dynamic> dto) async {
    final uri = Uri.parse('$baseUrl/empresas/solicitudes');
    final resp = await http.post(uri, headers: _headers, body: jsonEncode(dto));
    if (resp.statusCode == 200 || resp.statusCode == 201 || resp.statusCode == 204) return;
    throw Exception('Error ${resp.statusCode}: ${resp.body}');
  }
}
