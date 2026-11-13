import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';

/// Versiones de cuponera. Todos los métodos tienen fallback a cache en disco
/// para que la app siga funcionando offline.
class VersionesService {
  static const _kActivas = 'versiones:activas';
  static const _kPaginado = 'versiones:paginado';
  static String _kLocales(String versionId) => 'versiones:locales:$versionId';

  /// Lista versiones activas de cuponeras.
  /// Cuponeras para el selector de compra: precio, provincias, ciudades,
  /// nº de locales y distancia al local más cercano (si se envía ubicación).
  /// Si el backend aún no tiene `/versiones/disponibles`, usa el listado
  /// clásico (sin distancia) para no romper la compra.
  static Future<List<Map<String, dynamic>>> disponibles({double? lat, double? lng}) async {
    try {
      final resp = await ApiClient.instance.get(
        '/versiones/disponibles',
        queryParameters: {
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );
      if (resp.data is List) return List<Map<String, dynamic>>.from(resp.data);
    } catch (_) {}
    try {
      final base = await listarActivas();
      return base
          .map((v) => <String, dynamic>{
                '_id': v['_id'],
                'nombre': v['nombre'],
                'precio': v['precio'],
                'descripcion': v['descripcion'],
                'provincias': v['provinciasDisponibles'] ?? const [],
                'ciudades': v['ciudadesDisponibles'] ?? const [],
                'totalLocales': null,
                'distanciaKm': null,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> listarActivas() async {
    try {
      final resp = await ApiClient.instance.get(
        '/versiones/buscar/nombre',
        queryParameters: {'estado': 'true'},
      );
      if (resp.data is List) {
        final list = List<Map<String, dynamic>>.from(resp.data);
        await CacheService.I.write(_kActivas, list);
        return list;
      }
      return [];
    } catch (_) {
      final cached = await CacheService.I.read<List<dynamic>>(_kActivas);
      if (cached != null) {
        return cached.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)).toList();
      }
      rethrow;
    }
  }

  /// Caché en memoria del catálogo (perdura solo dentro de una sesión).
  static List<Map<String, dynamic>>? _activasCache;

  /// Versión paginada + cacheada. Si la sesión arranca con cache en disco,
  /// lo carga de inmediato sin tocar la red.
  static Future<List<Map<String, dynamic>>> listarActivasPaginado({
    bool force = false,
    int limit = 50,
  }) async {
    if (!force && _activasCache != null) return _activasCache!;
    try {
      final resp = await ApiClient.instance.get(
        '/versiones/buscar/paginado',
        queryParameters: {'estado': 'true', 'page': 1, 'limit': limit},
      );
      final body = resp.data;
      final list = (body is Map && body['data'] is List)
          ? body['data'] as List
          : const [];
      final out = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _activasCache = out;
      await CacheService.I.write(_kPaginado, out);
      return out;
    } catch (_) {
      final cached = await CacheService.I.read<List<dynamic>>(_kPaginado);
      if (cached != null) {
        final out = cached.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)).toList();
        _activasCache = out;
        return out;
      }
      rethrow;
    }
  }

  /// Locales disponibles para una versión (empate por ciudades).
  static Future<List<Map<String, dynamic>>> listarLocales(
      String versionId) async {
    try {
      final resp =
          await ApiClient.instance.get('/versiones/$versionId/locales');
      if (resp.data is List) {
        final list = List<Map<String, dynamic>>.from(resp.data);
        await CacheService.I.write(_kLocales(versionId), list);
        return list;
      }
      return [];
    } catch (_) {
      final cached =
          await CacheService.I.read<List<dynamic>>(_kLocales(versionId));
      if (cached != null) {
        return cached.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)).toList();
      }
      rethrow;
    }
  }
}
