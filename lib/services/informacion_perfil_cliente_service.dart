// lib/services/informacion_perfil_cliente_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/profile_info.dart';
import 'auth_service.dart';

class InformacionPerfilClienteService {
  final http.Client _client;
  InformacionPerfilClienteService({http.Client? client}) : _client = client ?? http.Client();

  Future<ProfileInfo> fetch() async {
    final base = dotenv.env['API_URL'] ?? '';
    final user = await AuthService().getUser();   // asume que tienes este método
    final userId = user?['_id'];
    final url = Uri.parse('$base/clientes/perfil/$userId'); // <-- ajusta tu endpoint


    final res = await _client.get(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      // si tu backend envuelve en { ok, data }, descomenta:
      // final data = json['data'] ?? json;
      // return ProfileInfo.fromJson(data);
      return ProfileInfo.fromJson(json);
    }

    debugPrint('❌ Perfil error ${res.statusCode}: ${res.body}');
    throw Exception('No se pudo obtener el perfil');
  }
}
