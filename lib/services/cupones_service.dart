// lib/services/cupones_service.dart
import 'dart:convert';
import 'package:enjoy/mappers/cuponera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../mappers/detalle_cupon.dart';

class CuponesService {
  final String base = dotenv.env['API_URL'] ?? '';

  /// Lista las cuponeras (cupones asignados) de un cliente
  /// GET /cupones/clientes/buscar/:clienteId?soloActivas=true
Future<List<Cuponera>> listarPorCliente(
  String clienteId, {bool soloActivas = true}
) async {
  final uri = Uri.parse('$base/cupones/clientes/buscar/$clienteId?soloActivas=$soloActivas');
  print('[CuponesService] ➡️ GET $uri');

  final resp = await http.get(uri);

  print('[CuponesService] ⬅️ Status: ${resp.statusCode}');
  // 1) Ver cuerpo crudo
  print('[CuponesService] ⬅️ Raw body: ${resp.body}');

  if (resp.statusCode != 200) {
    throw Exception('[CuponesService] ${resp.statusCode}: ${resp.body}');
  }

  // 2) Decodificar y loggear la forma
  dynamic decoded;
  try {
    decoded = jsonDecode(resp.body);
  } catch (e) {
    print('[CuponesService] ❌ jsonDecode falló: $e');
    rethrow;
  }

  print('[CuponesService] Tipo top-level: ${decoded.runtimeType}');

  if (decoded is! List) {
    // A veces el backend devuelve un objeto { data: [...] } u otro wrapper
    // Si fuera tu caso, ajusta aquí (por ejemplo: decoded['items'] o decoded['data'])
    throw Exception('[CuponesService] Se esperaba un List, vino ${decoded.runtimeType}');
  }

  final list = decoded as List;
  print('[CuponesService] Longitud lista: ${list.length}');

  // 3) Mapear con try/catch item-por-item para detectar campos problemáticos
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

      // Log rápido de los primeros ítems
      if (i < 3) {
        print('[CuponesService] ✅ Map OK [$i]: '
              'id=${c.id}, nombre=${c.nombre}, codigo=${c.codigo}, '
              'emitidaEl=${c.emitidaEl}, expiraEl=${c.expiraEl}, '
              'totalEscaneos=${c.totalEscaneos}, lastScanAt=${c.lastScanAt}');
      }
    } catch (e, st) {
      print('[CuponesService] ❌ Error mapeando item $i: $e');
      print(st);
      // Re-lanza si quieres cortar; o sigue para ver el resto:
      rethrow;
    }
  }

  print('[CuponesService] ✅ Mapeadas ${out.length} cuponeras');
  return out;
}


  /// Asignar un cupón a un cliente
  /// POST /cupones/clientes/:clienteId/cupones/:cuponId/asignar
  Future<void> asignarACiente(String clienteId, String cuponId) async {
    final uri = Uri.parse('$base/cupones/clientes/$clienteId/cupones/$cuponId/asignar');
    print('[CuponesService] ➡️ POST $uri');
    final resp = await http.post(uri);
    print('[CuponesService] ⬅️ ${resp.statusCode} ${resp.body}');
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('[CuponesService] ${resp.statusCode}: ${resp.body}');
    }
  }

    /// Detalle de cuponera por cupón (sin IDs en respuesta)
  /// GET /cupones/:cuponId/detalle
  Future<DetalleCupon> obtenerDetallePorCupon(String cuponId) async {
    final uri = Uri.parse('$base/cupones/$cuponId/detalle');
    print('[CuponesService] ➡️ GET $uri');

    final resp = await http.get(uri);
    print('[CuponesService] ⬅️ Status: ${resp.statusCode}');
    print('[CuponesService] ⬅️ Raw body: ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('[CuponesService] ${resp.statusCode}: ${resp.body}');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (e) {
      print('[CuponesService] ❌ jsonDecode falló: $e');
      rethrow;
    }

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

}
