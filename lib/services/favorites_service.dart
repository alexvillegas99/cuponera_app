import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';

/// Servicio de Favoritos. Offline:
///  - getIds devuelve los últimos IDs cacheados si la red falla.
///  - toggle/set requieren red (mutaciones) — el call site decide qué hacer.
class FavoritosService {
  static String _kIds(String clienteId) => 'favorites:ids:$clienteId';

  Future<Set<String>> getIds(String clienteId) async {
    try {
      final resp = await ApiClient.instance.get(
        '/clientes/$clienteId/favorites/ids',
      );
      final data = resp.data as Map<String, dynamic>;
      final ids = (data['ids'] as List).map((e) => e.toString()).toList();
      await CacheService.I.write(_kIds(clienteId), ids);
      return ids.toSet();
    } catch (_) {
      final cached =
          await CacheService.I.read<List<dynamic>>(_kIds(clienteId));
      if (cached != null) {
        return cached.map((e) => e.toString()).toSet();
      }
      rethrow;
    }
  }

  Future<bool> toggle(String clienteId, String negocioId) async {
    final resp = await ApiClient.instance.put(
      '/clientes/$clienteId/favorites/$negocioId',
    );
    final data = resp.data as Map<String, dynamic>;
    return data['isFavorite'] == true;
  }

  Future<void> set(String clienteId, String negocioId, bool fav) async {
    await ApiClient.instance.put(
      '/clientes/$clienteId/favorites/$negocioId?fav=${fav ? 'true' : 'false'}',
    );
  }
}
