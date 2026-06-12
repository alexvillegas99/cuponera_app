import 'package:enjoy/services/core/api_client.dart';

class CampanasService {
  Future<Map<String, dynamic>> feed({
    int page = 1,
    int limit = 20,
    bool soloNoLeidas = false,
  }) async {
    final resp = await ApiClient.instance.get(
      '/campanas/cliente/feed',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (soloNoLeidas) 'soloNoLeidas': 'true',
      },
    );
    return Map<String, dynamic>.from(resp.data);
  }

  Future<int> noLeidas() async {
    final resp = await ApiClient.instance.get('/campanas/cliente/no-leidas');
    return (resp.data?['total'] as num?)?.toInt() ?? 0;
  }

  Future<void> leerUna(String entregaId) async {
    await ApiClient.instance.post('/campanas/cliente/leer/$entregaId');
  }

  Future<void> leerTodas() async {
    await ApiClient.instance.post('/campanas/cliente/leer-todas');
  }

  Future<Map<String, dynamic>> getPrefs() async {
    final resp = await ApiClient.instance.get('/campanas/cliente/prefs');
    return Map<String, dynamic>.from(resp.data);
  }

  Future<void> setPrefs(Map<String, bool> prefs) async {
    await ApiClient.instance.patch('/campanas/cliente/prefs', data: prefs);
  }
}
