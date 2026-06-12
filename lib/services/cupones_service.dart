// lib/services/cupones_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enjoy/mappers/cuponera.dart';
import 'package:enjoy/services/core/api_client.dart';
import 'package:enjoy/services/core/api_exception.dart';
import '../mappers/detalle_cupon.dart';

class CuponesService {
  /// Lista las cuponeras (cupones asignados) de un cliente
  /// GET /cupones/clientes/buscar/:clienteId?soloActivas=true
Future<List<Cuponera>> listarPorCliente(
  String clienteId, {bool soloActivas = true}
) async {
  final path = '/cupones/clientes/buscar/$clienteId';
  print('[CuponesService] ➡️ GET $path');

  final resp = await ApiClient.instance.get(
    path,
    queryParameters: {'soloActivas': soloActivas.toString()},
  );

  print('[CuponesService] ⬅️ Status: ${resp.statusCode}');
  print('[CuponesService] ⬅️ Raw body: ${resp.data}');

  final dynamic decoded = resp.data;

  print('[CuponesService] Tipo top-level: ${decoded.runtimeType}');

  if (decoded is! List) {
    throw Exception('[CuponesService] Se esperaba un List, vino ${decoded.runtimeType}');
  }

  final list = decoded;
  print('[CuponesService] Longitud lista: ${list.length}');

  final out = <Cuponera>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is! Map<String, dynamic>) {
      print('[CuponesService] ⚠️ Item $i no es Map<String,dynamic>: ${item.runtimeType}');
      continue;
    }

    try {
      final c = Cuponera.fromJson(item);
      out.add(c);

      if (i < 3) {
        print('[CuponesService] ✅ Map OK [$i]: '
              'id=${c.id}, nombre=${c.nombre}, codigo=${c.codigo}, '
              'emitidaEl=${c.emitidaEl}, expiraEl=${c.expiraEl}, '
              'totalEscaneos=${c.totalEscaneos}, lastScanAt=${c.lastScanAt}');
      }
    } catch (e, st) {
      print('[CuponesService] ❌ Error mapeando item $i: $e');
      print(st);
      rethrow;
    }
  }

  print('[CuponesService] ✅ Mapeadas ${out.length} cuponeras');
  return out;
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

    /// Detalle de cuponera por cupón (sin IDs en respuesta)
  /// GET /cupones/:cuponId/detalle
  Future<DetalleCupon> obtenerDetallePorCupon(String cuponId) async {
    final path = '/cupones/$cuponId/detalle';
    print('[CuponesService] ➡️ GET $path');

    final resp = await ApiClient.instance.get(path);
    print('[CuponesService] ⬅️ Status: ${resp.statusCode}');
    print('[CuponesService] ⬅️ Raw body: ${resp.data}');

    final dynamic decoded = resp.data;

    if (decoded is! Map<String, dynamic>) {
      throw Exception('[CuponesService] Se esperaba Map, vino ${decoded.runtimeType}');
    }

    final detalle = DetalleCupon.fromJson(decoded);
    print('[CuponesService] ✅ Detalle OK | '
          'escaneados=${detalle.lugaresScaneados.length} | '
          'sinScannear=${detalle.lugaresSinScannear.length} | '
          'totalEscaneos=${detalle.totalEscaneos}');
    return detalle;
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
  Future<List<String>> localesDisponibles(String clienteId) async {
    final resp = await ApiClient.instance.get(
      '/cupones/clientes/$clienteId/locales-disponibles',
    );
    if (resp.data is List) {
      return (resp.data as List).map((e) => e.toString()).toList();
    }
    return [];
  }
}
