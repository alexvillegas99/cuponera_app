// lib/services/informacion_perfil_cliente_service.dart
import 'package:flutter/foundation.dart';
import 'package:enjoy/services/core/api_client.dart';
import '../models/profile_info.dart';
import 'auth_service.dart';

class InformacionPerfilClienteService {
  Future<ProfileInfo> fetch() async {
    final user = await AuthService().getUser();   // asume que tienes este método
    final userId = user?['_id'];

    final resp = await ApiClient.instance.get('/clientes/perfil/$userId');

    if (resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300) {
      final json = resp.data;
      return ProfileInfo.fromJson(json);
    }

    debugPrint('❌ Perfil error ${resp.statusCode}: ${resp.data}');
    throw Exception('No se pudo obtener el perfil');
  }
}
