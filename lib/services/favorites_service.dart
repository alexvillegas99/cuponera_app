import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Servicio de Favoritos (sin autenticación)
/// Rutas backend:
///  - GET /clientes/:clienteId/favorites/ids               -> { ids: string[] }
///  - PUT /clientes/:clienteId/favorites/:negocioId        -> toggle
///  - PUT /clientes/:clienteId/favorites/:negocioId?fav=.. -> set idempotente
class FavoritosService {
  final String base = dotenv.env['API_URL'] ?? '';

  Future<Set<String>> getIds(String clienteId) async {
    final uri = Uri.parse('$base/clientes/$clienteId/favorites/ids');
    print('[FavoritosService] ➡️ GET $uri');
    final resp = await http.get(uri);
    print('[FavoritosService] ⬅️ ${resp.statusCode} ${resp.body}');
    if (resp.statusCode != 200) {
      throw Exception('[FavoritosService] ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['ids'] as List).map((e) => e.toString()).toSet();
  }

  Future<bool> toggle(String clienteId, String negocioId) async {
    final uri = Uri.parse('$base/clientes/$clienteId/favorites/$negocioId');
    print('[FavoritosService] ➡️ PUT (toggle) $uri');
    final resp = await http.put(uri);
    print('[FavoritosService] ⬅️ ${resp.statusCode} ${resp.body}');
    if (resp.statusCode != 200) {
      throw Exception('[FavoritosService] ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['isFavorite'] == true;
  }

  Future<void> set(String clienteId, String negocioId, bool fav) async {
    final uri = Uri.parse(
      '$base/clientes/$clienteId/favorites/$negocioId?fav=${fav ? 'true' : 'false'}',
    );
    print('[FavoritosService] ➡️ PUT (set=$fav) $uri');
    final resp = await http.put(uri);
    print('[FavoritosService] ⬅️ ${resp.statusCode} ${resp.body}');
    if (resp.statusCode != 200) {
      throw Exception('[FavoritosService] ${resp.statusCode}: ${resp.body}');
    }
  }
}
