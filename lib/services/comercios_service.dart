import 'package:enjoy/services/core/api_client.dart';
import 'package:enjoy/mappers/comercio_mini.dart';

class ComerciosService {
  /// GET /comercios/:usuarioId/detalle-mini
  Future<ComercioMini> obtenerInformacionComercioMini(String usuarioId) async {
    final path = '/usuarios/$usuarioId/detalle-mini';
    print('[ComerciosService] ➡️ GET $path');

    final resp = await ApiClient.instance.get(path);
    print('[ComerciosService] ⬅️ ${resp.statusCode}');
    print('[ComerciosService] ⬅️ ${resp.data}');

    final decoded = resp.data;
    if (decoded is! Map<String, dynamic>) {
      throw Exception('[ComerciosService] Esperaba objeto JSON, vino ${decoded.runtimeType}');
    }

    return ComercioMini.fromJson(decoded);
  }



}
