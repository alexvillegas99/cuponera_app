// lib/services/categorias_service.dart
import 'package:enjoy/services/core/api_client.dart';
import '../models/categoria.dart';

class CategoriasService {
  Future<List<Categoria>> getActivas() async {
    final path = '/categorias';
    print('[CategoriasService] ➡️ GET $path?estado=true');

    try {
      final resp = await ApiClient.instance.get(
        path,
        queryParameters: {'estado': 'true'},
      );

      print('[CategoriasService] ⬅️ Status: ${resp.statusCode}');
      print('[CategoriasService] ⬅️ Body: ${resp.data}');

      if (resp.statusCode == 200) {
        final List data = resp.data as List;
        print('[CategoriasService] ✅ Decodificadas ${data.length} categorías');
        return data
            .map((e) => Categoria.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            '[CategoriasService] ❌ Error ${resp.statusCode}: ${resp.data}');
      }
    } catch (e) {
      print('[CategoriasService] ⚠️ Excepción: $e');
      rethrow;
    }
  }
}
