// lib/services/promotions_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/promotion_models.dart';
import '../mappers/promotion_mapper.dart';

class PromotionsService {
  final String base = dotenv.env['API_URL'] ?? '';

  /// 🔹 Trae todas las promos activas (ajusta el endpoint según tu backend)
  Future<List<Promotion>> getAllActivePromos() async {
    // Si tienes un endpoint específico, cámbialo aquí.
    // Por ejemplo: final uri = Uri.parse('$base/promos/activas');
    // Mientras, uso el de usuarios/por-ciudades con param vacío (si devuelve todo):
    final uri = Uri.parse('$base/usuarios/por-ciudades?ciudades=68b68090af6e4afed306d1a4');

    print('[PromotionsService] ➡️ GET $uri');
    final resp = await http.get(uri);

    print('[PromotionsService] ⬅️ Status: ${resp.statusCode}');
    if (resp.statusCode != 200) {
      print('[PromotionsService] ❌ Body: ${resp.body}');
      throw Exception('Error ${resp.statusCode}: ${resp.body}');
    }

    final List data = jsonDecode(resp.body) as List;
    print('[PromotionsService] ✅ Items: ${data.length}');
    print('[PromotionsService] ✅ Items: ${data}');
    return data
        .map((e) => mapBackendItemToPromotion(e as Map<String, dynamic>))
        .toList();
  }

  /// 🔹 Trae promos filtrando por IDs de ciudades
  /// Tu backend espera: /usuarios/por-ciudades?ciudades=id1,id2,id3
  Future<List<Promotion>> getByCityIds(List<String> ciudadIds) async {
    final joined = ciudadIds.join(',');
    final uri = Uri.parse('$base/usuarios/por-ciudades?ciudades=$joined');

    print('[PromotionsService] ➡️ GET $uri');
    final resp = await http.get(uri);

    print('[PromotionsService] ⬅️ Status: ${resp.statusCode}');
    if (resp.statusCode != 200) {
      print('[PromotionsService] ❌ Body: ${resp.body}');
      throw Exception('Error ${resp.statusCode}: ${resp.body}');
    }

    final List data = jsonDecode(resp.body) as List;
    print('[PromotionsService] ✅ Items: ${data.length}');

    return data
        .map((e) => mapBackendItemToPromotion(e as Map<String, dynamic>))
        .toList();
  }
}
