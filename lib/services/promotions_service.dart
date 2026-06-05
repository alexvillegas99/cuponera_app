// lib/services/promotions_service.dart
import 'package:enjoy/services/core/api_client.dart';

import '../models/promotion_models.dart';
import '../mappers/promotion_mapper.dart';

class PromotionsService {
  /// 🔹 Trae todas las promos activas (ajusta el endpoint según tu backend)
Future<List<Promotion>> getAllActivePromos({
  List<String>? cityIds,
}) async {
  final Map<String, dynamic> params = {};
  if (cityIds != null && cityIds.isNotEmpty) {
    params['ciudades'] = cityIds.join(',');
  }

  print('[PromotionsService] ➡️ GET /usuarios/por-ciudades params=$params');
  final resp = await ApiClient.instance.get(
    '/usuarios/por-ciudades',
    queryParameters: params.isEmpty ? null : params,
  );

  print('[PromotionsService] ⬅️ Status: ${resp.statusCode}');
  if (resp.statusCode != 200) {
    print('[PromotionsService] ❌ Body: ${resp.data}');
    throw Exception('Error ${resp.statusCode}: ${resp.data}');
  }

  final List data = resp.data as List;
  print('[PromotionsService] ✅ Items: ${data.length}');
  return data
      .map((e) => mapBackendItemToPromotion(e as Map<String, dynamic>))
      .toList();
}
  /// 🔹 Trae TODAS las promos de una provincia (el backend expande a sus ciudades).
  /// Endpoint: /usuarios/por-provincia?provincia=<id>
  Future<List<Promotion>> getByProvincia(String provinciaId) async {
    final resp = await ApiClient.instance.get(
      '/usuarios/por-provincia',
      queryParameters: {'provincia': provinciaId},
    );
    if (resp.statusCode != 200) {
      throw Exception('Error ${resp.statusCode}: ${resp.data}');
    }
    final List data = resp.data as List;
    return data
        .map((e) => mapBackendItemToPromotion(e as Map<String, dynamic>))
        .toList();
  }

  /// 🔹 Trae las promos de VARIAS provincias (merge deduplicado por id).
  Future<List<Promotion>> getByProvincias(List<String> provinciaIds) async {
    final results = await Future.wait(
      provinciaIds.map((id) => getByProvincia(id)),
    );
    final seen = <String>{};
    final out = <Promotion>[];
    for (final list in results) {
      for (final p in list) {
        if (seen.add(p.id)) out.add(p);
      }
    }
    return out;
  }

  /// 🔹 Trae promos filtrando por IDs de ciudades
  /// Tu backend espera: /usuarios/por-ciudades?ciudades=id1,id2,id3
  Future<List<Promotion>> getByCityIds(List<String> ciudadIds) async {
    final joined = ciudadIds.join(',');

    print('[PromotionsService] ➡️ GET /usuarios/por-ciudades?ciudades=$joined');
    final resp = await ApiClient.instance.get(
      '/usuarios/por-ciudades',
      queryParameters: {'ciudades': joined},
    );

    print('[PromotionsService] ⬅️ Status: ${resp.statusCode}');
    if (resp.statusCode != 200) {
      print('[PromotionsService] ❌ Body: ${resp.data}');
      throw Exception('Error ${resp.statusCode}: ${resp.data}');
    }

    final List data = resp.data as List;
    print('[PromotionsService] ✅ Items: ${data.length}');

    return data
        .map((e) => mapBackendItemToPromotion(e as Map<String, dynamic>))
        .toList();
  }
}
