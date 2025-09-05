// lib/services/compartidos_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

enum CanalCompartir { whatsapp, sistema }

class CompartidosService {
  final String base = dotenv.env['API_URL'] ?? '';

  Future<void> registrar({
    required String clienteId,  // tu id de cliente logueado
    required String usuarioId,  // el admin-local del comercio
    required CanalCompartir canal,
    String? telefonoDestino,
    String? mensaje,
    String? origen,             // 'comercio' | 'cupon'
    String? origenId,
  }) async {
    final uri = Uri.parse('$base/compartidos');
    final body = {
      'clienteId': clienteId,
      'usuarioId': usuarioId,
      'canal': canal.name,
      if (telefonoDestino != null && telefonoDestino.isNotEmpty) 'telefonoDestino': telefonoDestino,
      if (mensaje != null && mensaje.isNotEmpty) 'mensaje': mensaje,
      if (origen != null) 'origen': origen,
      if (origenId != null) 'origenId': origenId,
    };

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('[CompartidosService] ${resp.statusCode}: ${resp.body}');
    }
  }
}
