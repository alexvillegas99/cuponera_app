// lib/services/ciudades_service.dart
import 'package:flutter/material.dart';
import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';
import '../models/ciudad.dart';
import '../models/provincia.dart';

/// Endpoints de catálogos territoriales. Cada método aplica
/// stale-while-revalidate: si el back falla, devuelve lo último cacheado.
class CiudadesService {
  static const _kProvinciasActivas = 'catalog:provincias:activas';
  static String _kRegistro(String? provinciaId) =>
      'catalog:ciudades:registro:${provinciaId ?? "all"}';
  static String _kPromosPorProvincia(String provinciaId) =>
      'catalog:ciudades:promos:$provinciaId';
  static const _kPromosTodas = 'catalog:ciudades:promos:all';

  Future<List<Provincia>> getProvincias() async {
    try {
      final resp = await ApiClient.instance.get('/provincias/activas');
      if (resp.statusCode == 200) {
        await CacheService.I.write(_kProvinciasActivas, resp.data);
        return Provincia.listFrom(resp.data);
      }
      throw Exception('Error ${resp.statusCode}: ${resp.data}');
    } catch (e) {
      final cached = await CacheService.I.read<List<dynamic>>(_kProvinciasActivas);
      if (cached != null) return Provincia.listFrom(cached);
      rethrow;
    }
  }

  Future<List<Ciudad>> getParaRegistro({String? provinciaId}) async {
    final params = <String, dynamic>{};
    if (provinciaId != null && provinciaId.isNotEmpty) {
      params['provincia'] = provinciaId;
    }
    try {
      final resp = await ApiClient.instance.get(
        '/ciudades/registro',
        queryParameters: params.isEmpty ? null : params,
      );
      if (resp.statusCode == 200) {
        await CacheService.I.write(_kRegistro(provinciaId), resp.data);
        return (resp.data as List)
            .map((e) => Ciudad.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Error ${resp.statusCode}: ${resp.data}');
    } catch (e) {
      final cached =
          await CacheService.I.read<List<dynamic>>(_kRegistro(provinciaId));
      if (cached != null) {
        return cached
            .map((e) => Ciudad.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  Future<List<Ciudad>> getParaPromosPorProvincia(String provinciaId) async {
    try {
      final resp = await ApiClient.instance.get(
        '/ciudades/promociones',
        queryParameters: {'provincia': provinciaId},
      );
      if (resp.statusCode == 200) {
        await CacheService.I
            .write(_kPromosPorProvincia(provinciaId), resp.data);
        return (resp.data as List)
            .map((e) => Ciudad.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Error ${resp.statusCode}: ${resp.data}');
    } catch (e) {
      final cached = await CacheService.I
          .read<List<dynamic>>(_kPromosPorProvincia(provinciaId));
      if (cached != null) {
        return cached
            .map((e) => Ciudad.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  Future<List<Ciudad>> getParaPromos() async {
    try {
      final resp = await ApiClient.instance.get('/ciudades/promociones');
      if (resp.statusCode == 200) {
        await CacheService.I.write(_kPromosTodas, resp.data);
        return (resp.data as List)
            .map((e) => Ciudad.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Error ${resp.statusCode}: ${resp.data}');
    } catch (e, st) {
      debugPrint('CiudadesService offline fallback: $e');
      debugPrint('$st');
      final cached = await CacheService.I.read<List<dynamic>>(_kPromosTodas);
      if (cached != null) {
        return cached
            .map((e) => Ciudad.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }
}
