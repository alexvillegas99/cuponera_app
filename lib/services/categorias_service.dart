// lib/services/categorias_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/categoria.dart';

class CategoriasService {
  final String base = dotenv.env['API_URL'] ?? '';

  Future<List<Categoria>> getActivas() async {
    final uri = Uri.parse('$base/categorias?estado=true');
    print('[CategoriasService] ➡️ GET $uri');

    try {
      final resp = await http.get(uri);

      print('[CategoriasService] ⬅️ Status: ${resp.statusCode}');
      print('[CategoriasService] ⬅️ Body: ${resp.body}');

      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body) as List;
        print('[CategoriasService] ✅ Decodificadas ${data.length} categorías');
        return data
            .map((e) => Categoria.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            '[CategoriasService] ❌ Error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      print('[CategoriasService] ⚠️ Excepción: $e');
      rethrow;
    }
  }
}
