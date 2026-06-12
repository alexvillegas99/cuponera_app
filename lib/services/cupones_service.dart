// lib/services/cupones_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enjoy/mappers/cuponera.dart';
import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';
import 'package:enjoy/services/core/api_exception.dart';
import '../mappers/detalle_cupon.dart';

class CuponesService {
  static String _kListar(String clienteId, bool soloActivas) =>
      'cupones:listar:$clienteId:$soloActivas';
  static String _kDetalle(String cuponId) => 'cupones:detalle:$cuponId';
  static String _kLocalesDisp(String clienteId) =>
      'cupones:locales-disp:$clienteId';

  /// Lista las cuponeras de un cliente con fallback a cache.
  /// GET /cupones/clientes/buscar/:clienteId?soloActivas=true
  Future<List<Cuponera>> listarPorCliente(
    String clienteId, {
    bool soloActivas = true,
  }) async {
    try {
      final resp = await ApiClient.instance.get(
        '/cupones/clientes/buscar/$clienteId',
        queryParameters: {'soloActivas': soloActivas.toString()},
      );
      final decoded = resp.data;
      if (decoded is! List) {
        throw Exception('Se esperaba un List, vino ${decoded.runtimeType}');
      }
      final out = <Cuponera>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            out.add(Cuponera.fromJson(item));
          } catch (_) {}
        }
      }
      await CacheService.I.write(_kListar(clienteId, soloActivas), decoded);
      return out;
    } catch (e) {
      final cached = await CacheService.I
          .read<List<dynamic>>(_kListar(clienteId, soloActivas));
      if (cached != null) {
        final out = <Cuponera>[];
        for (final item in cached) {
          if (item is Map) {
            try {
              out.add(Cuponera.fromJson(Map<String, dynamic>.from(item)));
            } catch (_) {}
          }
        }
        return out;
      }
      rethrow;
    }
  }

  /// Caché en memoria de las cuponeras del cliente (por clienteId+soloActivas).
  /// Solo se refresca con [force] (pull-to-refresh).
  static final Map<String, List<Cuponera>> _cuponerasCache = {};

  /// Versión paginada + cacheada (endpoint nuevo aditivo). Mismo shape que
  /// listarPorCliente, pero usa /cuponeras-paginado y cachea en memoria.
  Future<List<Cuponera>> listarPorClientePaginado(
    String clienteId, {
    bool soloActivas = true,
    bool force = false,
    int limit = 50,
  }) async {
    final key = '$clienteId|$soloActivas';
    if (!force && _cuponerasCache.containsKey(key)) {
      return _cuponerasCache[key]!;
    }
    try {
      final resp = await ApiClient.instance.get(
        '/cupones/clientes/$clienteId/cuponeras-paginado',
        queryParameters: {
          'soloActivas': soloActivas.toString(),
          'page': 1,
          'limit': limit,
        },
      );
      final body = resp.data;
      final raw = (body is Map && body['data'] is List)
          ? body['data'] as List
          : const [];
      final out = _parseCuponeras(raw);
      _cuponerasCache[key] = out;
      // Persistir para uso offline.
      await _persistCuponeras(key, raw);
      return out;
    } catch (e) {
      // Sin conexión / error → devolver lo cacheado en disco (offline).
      final cached = await _loadPersistedCuponeras(key);
      if (cached != null) {
        _cuponerasCache[key] = cached;
        return cached;
      }
      rethrow;
    }
  }

  List<Cuponera> _parseCuponeras(List raw) {
    final out = <Cuponera>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        try {
          out.add(Cuponera.fromJson(item));
        } catch (_) {}
      }
    }
    return out;
  }

  Future<void> _persistCuponeras(String key, List raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cuponeras_cache_$key', jsonEncode(raw));
    } catch (_) {}
  }

  Future<List<Cuponera>?> _loadPersistedCuponeras(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('cuponeras_cache_$key');
      if (str == null) return null;
      final decoded = jsonDecode(str);
      if (decoded is! List) return null;
      return _parseCuponeras(decoded);
    } catch (_) {
      return null;
    }
  }


Future<Map<String, dynamic>> findByIdRaw(String cuponId) async {
  final path = '/cupones/agregar/$cuponId';

  try {
    final resp = await ApiClient.instance.get(path);
    final decoded = resp.data;
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(500, 'Respuesta inesperada del servidor.');
    }
    return Map<String, dynamic>.from(decoded);
  } on DioException catch (e) {
    final statusCode = e.response?.statusCode ?? 500;
    String msg = 'Error $statusCode';
    try {
      final d = e.response?.data;
      if (d is Map && d['message'] is Map && d['message']['message'] is String) {
        msg = d['message']['message'] as String;
      }
    } catch (_) {}
    throw ApiException(statusCode, msg);
  }
}

  /// Asignar un cupón a un cliente
  /// POST /cupones/clientes/:clienteId/cupones/:cuponId/asignar
  Future<void> asignarACliente(String clienteId, String cuponId) async {
    final path = '/cupones/clientes/$clienteId/cupones/$cuponId/asignar';
    print('[CuponesService] ➡️ POST $path');
    final resp = await ApiClient.instance.post(path);
    print('[CuponesService] ⬅️ ${resp.statusCode} ${resp.data}');
  }

  /// Detalle de cuponera por cupón con fallback a cache.
  /// GET /cupones/:cuponId/detalle
  Future<DetalleCupon> obtenerDetallePorCupon(String cuponId) async {
    try {
      final resp = await ApiClient.instance.get('/cupones/$cuponId/detalle');
      final decoded = resp.data;
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Se esperaba Map, vino ${decoded.runtimeType}');
      }
      await CacheService.I.write(_kDetalle(cuponId), decoded);
      return DetalleCupon.fromJson(decoded);
    } catch (e) {
      final cached =
          await CacheService.I.read<Map<String, dynamic>>(_kDetalle(cuponId));
      if (cached != null) return DetalleCupon.fromJson(cached);
      rethrow;
    }
  }

  /// Cupones disponibles de un cliente para canjear en un local específico
  Future<List<Map<String, dynamic>>> disponiblesParaLocal(
    String clienteId,
    String usuarioId,
  ) async {
    final resp = await ApiClient.instance.get(
      '/cupones/clientes/$clienteId/disponibles/$usuarioId',
    );

    if (resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    return [];
  }

  /// 🎁 El destinatario abre su regalo. Marca regaloAbierto=true en backend.
  /// PATCH /cupones/:cuponId/abrir-regalo  body { clienteId }
  Future<bool> abrirRegalo(String cuponId, String clienteId) async {
    try {
      final resp = await ApiClient.instance.patch(
        '/cupones/$cuponId/abrir-regalo',
        data: {'clienteId': clienteId},
      );
      // Invalidar caché de cuponeras para que el siguiente listado refleje
      // regaloAbierto=true.
      _cuponerasCache.clear();
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// 🎁 Buscar destinatario para un regalo por email o identificación.
  /// GET /clientes/buscar-destinatario?q=...
  /// Devuelve {exists, id?, nombre?, email?}.
  Future<Map<String, dynamic>> buscarDestinatario(String q) async {
    try {
      final resp = await ApiClient.instance.get(
        '/clientes/buscar-destinatario',
        queryParameters: {'q': q},
      );
      if (resp.data is Map) {
        return Map<String, dynamic>.from(resp.data);
      }
    } catch (_) {}
    return {'exists': false};
  }

  /// Ids de los locales donde el cliente tiene cupón disponible para canjear.
  /// Fallback a cache: el filtro "solo con cupón" sigue funcionando offline.
  Future<List<String>> localesDisponibles(String clienteId) async {
    try {
      final resp = await ApiClient.instance.get(
        '/cupones/clientes/$clienteId/locales-disponibles',
      );
      if (resp.data is List) {
        final list = (resp.data as List).map((e) => e.toString()).toList();
        await CacheService.I.write(_kLocalesDisp(clienteId), list);
        return list;
      }
      return [];
    } catch (_) {
      final cached = await CacheService.I
          .read<List<dynamic>>(_kLocalesDisp(clienteId));
      if (cached != null) return cached.map((e) => e.toString()).toList();
      return [];
    }
  }
}
