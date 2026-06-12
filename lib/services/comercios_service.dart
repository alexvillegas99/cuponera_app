import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';
import 'package:enjoy/mappers/comercio_mini.dart';

class ComerciosService {
  static String _key(String usuarioId) => 'comercio:detalle:$usuarioId';

  /// GET /usuarios/:usuarioId/detalle-mini con fallback a cache.
  /// El detalle de un local que el cliente ya visitó queda disponible aunque
  /// vuelva a entrar offline.
  Future<ComercioMini> obtenerInformacionComercioMini(String usuarioId) async {
    try {
      final resp =
          await ApiClient.instance.get('/usuarios/$usuarioId/detalle-mini');
      final decoded = resp.data;
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Esperaba objeto JSON, vino ${decoded.runtimeType}');
      }
      await CacheService.I.write(_key(usuarioId), decoded);
      return ComercioMini.fromJson(decoded);
    } catch (e) {
      final cached =
          await CacheService.I.read<Map<String, dynamic>>(_key(usuarioId));
      if (cached != null) return ComercioMini.fromJson(cached);
      rethrow;
    }
  }
}
