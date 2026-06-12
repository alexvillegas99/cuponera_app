// lib/services/categorias_service.dart
import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';
import '../models/categoria.dart';

class CategoriasService {
  static const _cacheKey = 'catalog:categorias:activas';

  Future<List<Categoria>> getActivas() async {
    try {
      final resp = await ApiClient.instance.get(
        '/categorias',
        queryParameters: {'estado': 'true'},
      );
      if (resp.statusCode == 200) {
        final List data = resp.data as List;
        await CacheService.I.write(_cacheKey, data);
        return data
            .map((e) => Categoria.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Error ${resp.statusCode}: ${resp.data}');
    } catch (e) {
      // Offline o backend caído → devolvemos lo último cacheado.
      final cached = await CacheService.I.read<List<dynamic>>(_cacheKey);
      if (cached != null) {
        return cached
            .map((e) => Categoria.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }
}
