// lib/services/cupones_service.dart
import 'package:dio/dio.dart';
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
}
