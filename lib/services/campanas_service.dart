import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';

/// Notificaciones del cliente. Offline:
///  - feed devuelve la última página 1 cacheada.
///  - noLeidas devuelve el último contador cacheado.
///  - prefs siempre cacheadas para que la pantalla de prefs abra sin red.
///  - leerUna/leerTodas/setPrefs requieren red (no críticos offline).
class CampanasService {
  static const _kFeedP1 = 'campanas:feed:p1';
  static const _kNoLeidas = 'campanas:no-leidas';
  static const _kPrefs = 'campanas:prefs';

  Future<Map<String, dynamic>> feed({
    int page = 1,
    int limit = 20,
    bool soloNoLeidas = false,
  }) async {
    try {
      final resp = await ApiClient.instance.get(
        '/campanas/cliente/feed',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (soloNoLeidas) 'soloNoLeidas': 'true',
        },
      );
      final data = Map<String, dynamic>.from(resp.data);
      // Sólo cacheamos la página 1 sin filtros — es lo que pinta el badge
      // y la bandeja vacía al arrancar.
      if (page == 1 && !soloNoLeidas) {
        await CacheService.I.write(_kFeedP1, data);
      }
      return data;
    } catch (_) {
      if (page == 1 && !soloNoLeidas) {
        final cached =
            await CacheService.I.read<Map<String, dynamic>>(_kFeedP1);
        if (cached != null) return Map<String, dynamic>.from(cached);
      }
      rethrow;
    }
  }

  Future<int> noLeidas() async {
    try {
      final resp = await ApiClient.instance.get('/campanas/cliente/no-leidas');
      final total = (resp.data?['total'] as num?)?.toInt() ?? 0;
      await CacheService.I.write(_kNoLeidas, total);
      return total;
    } catch (_) {
      final cached = await CacheService.I.read<int>(_kNoLeidas);
      return cached ?? 0;
    }
  }

  Future<void> leerUna(String entregaId) async {
    await ApiClient.instance.post('/campanas/cliente/leer/$entregaId');
  }

  Future<void> leerTodas() async {
    await ApiClient.instance.post('/campanas/cliente/leer-todas');
  }

  /** Borra UNA notificación de la bandeja del cliente actual. */
  Future<void> eliminarEntrega(String entregaId) async {
    await ApiClient.instance.delete('/campanas/cliente/entrega/$entregaId');
  }

  /** Vacía toda la bandeja del cliente actual. */
  Future<void> vaciarBandeja() async {
    await ApiClient.instance.delete('/campanas/cliente/entregas');
  }

  Future<Map<String, dynamic>> getPrefs() async {
    try {
      final resp = await ApiClient.instance.get('/campanas/cliente/prefs');
      final data = Map<String, dynamic>.from(resp.data);
      await CacheService.I.write(_kPrefs, data);
      return data;
    } catch (_) {
      final cached = await CacheService.I.read<Map<String, dynamic>>(_kPrefs);
      if (cached != null) return Map<String, dynamic>.from(cached);
      rethrow;
    }
  }

  Future<void> setPrefs(Map<String, bool> prefs) async {
    await ApiClient.instance.patch('/campanas/cliente/prefs', data: prefs);
    await CacheService.I.write(_kPrefs, prefs);
  }
}
