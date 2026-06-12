// lib/services/informacion_perfil_cliente_service.dart
import 'package:flutter/foundation.dart';
import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';
import '../models/profile_info.dart';
import 'auth_service.dart';

class InformacionPerfilClienteService {
  static String _key(String userId) => 'profile:cliente:$userId';

  Future<ProfileInfo> fetch() async {
    final user = await AuthService().getUser();
    final userId = user?['_id'];
    if (userId == null) throw Exception('Sin sesión');

    try {
      final resp = await ApiClient.instance.get('/clientes/perfil/$userId');
      if (resp.statusCode != null &&
          resp.statusCode! >= 200 &&
          resp.statusCode! < 300) {
        final json = resp.data;
        await CacheService.I.write(_key(userId.toString()), json);
        return ProfileInfo.fromJson(json);
      }
      debugPrint('❌ Perfil error ${resp.statusCode}: ${resp.data}');
      throw Exception('No se pudo obtener el perfil');
    } catch (e) {
      final cached = await CacheService.I
          .read<Map<String, dynamic>>(_key(userId.toString()));
      if (cached != null) return ProfileInfo.fromJson(cached);
      rethrow;
    }
  }
}
