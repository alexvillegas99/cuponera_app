import 'package:enjoy/services/core/api_client.dart';

/// Servicio de Favoritos (sin autenticación)
/// Rutas backend:
///  - GET /clientes/:clienteId/favorites/ids               -> { ids: string[] }
///  - PUT /clientes/:clienteId/favorites/:negocioId        -> toggle
///  - PUT /clientes/:clienteId/favorites/:negocioId?fav=.. -> set idempotente
class FavoritosService {
  Future<Set<String>> getIds(String clienteId) async {
    final path = '/clientes/$clienteId/favorites/ids';
    print('[FavoritosService] ➡️ GET $path');
    final resp = await ApiClient.instance.get(path);
    print('[FavoritosService] ⬅️ ${resp.statusCode} ${resp.data}');
    final data = resp.data as Map<String, dynamic>;
    return (data['ids'] as List).map((e) => e.toString()).toSet();
  }

  Future<bool> toggle(String clienteId, String negocioId) async {
    final path = '/clientes/$clienteId/favorites/$negocioId';
    print('[FavoritosService] ➡️ PUT (toggle) $path');
    final resp = await ApiClient.instance.put(path);
    print('[FavoritosService] ⬅️ ${resp.statusCode} ${resp.data}');
    final data = resp.data as Map<String, dynamic>;
    return data['isFavorite'] == true;
  }

  Future<void> set(String clienteId, String negocioId, bool fav) async {
    final path = '/clientes/$clienteId/favorites/$negocioId?fav=${fav ? 'true' : 'false'}';
    print('[FavoritosService] ➡️ PUT (set=$fav) $path');
    final resp = await ApiClient.instance.put(path);
    print('[FavoritosService] ⬅️ ${resp.statusCode} ${resp.data}');
  }
}
