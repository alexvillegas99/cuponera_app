import 'package:enjoy/services/cache_service.dart';
import 'package:enjoy/services/core/api_client.dart';

/// Servicio HTTP para el chat (Modelo Soporte: 1 hilo por local + bandeja).
class ChatService {
  static const _kMiHilo = 'chat:mi-hilo';
  static String _kMensajes(String hiloId) => 'chat:mensajes:$hiloId';

  /// Para usuarios soporte: lista paginada de hilos.
  /// Para admin-local / staff: devuelve solo SU hilo.
  Future<Map<String, dynamic>> listarHilos({
    String? q,
    String? estado, // 'ABIERTA' | 'CERRADA'
    bool asignadoMi = false,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (estado != null) params['estado'] = estado;
    if (asignadoMi) params['asignadoMi'] = 'true';
    final resp =
        await ApiClient.instance.get('/chat/hilos', queryParameters: params);
    return Map<String, dynamic>.from(resp.data);
  }

  /// Devuelve (o crea) el hilo del local actual. Fallback a cache para que
  /// la pantalla de soporte muestre el hilo aunque la red falle (el envío
  /// de mensajes nuevos seguirá requiriendo red).
  Future<Map<String, dynamic>> miHilo() async {
    try {
      final resp = await ApiClient.instance.get('/chat/mi-hilo');
      final data = Map<String, dynamic>.from(resp.data);
      await CacheService.I.write(_kMiHilo, data);
      return data;
    } catch (_) {
      final cached =
          await CacheService.I.read<Map<String, dynamic>>(_kMiHilo);
      if (cached != null) return Map<String, dynamic>.from(cached);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> obtenerHilo(String id) async {
    final resp = await ApiClient.instance.get('/chat/hilos/$id');
    return Map<String, dynamic>.from(resp.data);
  }

  /// Cuenta de no-leídos del usuario actual.
  Future<int> contadorNoLeidos() async {
    final resp = await ApiClient.instance.get('/chat/no-leidos');
    return (resp.data?['total'] as num?)?.toInt() ?? 0;
  }

  /// Mensajes paginados (cursor = id del último mensaje cargado hacia atrás).
  /// Sólo cacheamos la primera página (cursor=null) — al volver al chat
  /// offline el cliente ve los últimos mensajes pero no puede paginar más.
  Future<Map<String, dynamic>> mensajes(
    String hiloId, {
    String? cursor,
    int limit = 30,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;
    try {
      final resp = await ApiClient.instance
          .get('/chat/hilos/$hiloId/mensajes', queryParameters: params);
      final data = Map<String, dynamic>.from(resp.data);
      if (cursor == null) {
        await CacheService.I.write(_kMensajes(hiloId), data);
      }
      return data;
    } catch (_) {
      if (cursor == null) {
        final cached = await CacheService.I
            .read<Map<String, dynamic>>(_kMensajes(hiloId));
        if (cached != null) return Map<String, dynamic>.from(cached);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> enviar(
    String hiloId, {
    String? texto,
    String? imagenBase64,
  }) async {
    final resp = await ApiClient.instance.post(
      '/chat/hilos/$hiloId/mensajes',
      data: {
        if (texto != null && texto.isNotEmpty) 'texto': texto,
        if (imagenBase64 != null && imagenBase64.isNotEmpty)
          'imagenBase64': imagenBase64,
      },
    );
    return Map<String, dynamic>.from(resp.data);
  }

  Future<void> marcarLeidos(String hiloId) async {
    await ApiClient.instance.post('/chat/hilos/$hiloId/leer');
  }

  Future<Map<String, dynamic>> asignar(String hiloId, {String? agenteId}) async {
    final resp = await ApiClient.instance.patch(
      '/chat/hilos/$hiloId/asignar',
      data: {if (agenteId != null) 'agenteId': agenteId},
    );
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> cerrar(String hiloId) async {
    final resp = await ApiClient.instance.patch('/chat/hilos/$hiloId/cerrar');
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> reabrir(String hiloId) async {
    final resp = await ApiClient.instance.patch('/chat/hilos/$hiloId/reabrir');
    return Map<String, dynamic>.from(resp.data);
  }

  // ── Presencia multi-agente ────────────────────────────────────────
  Future<Map<String, dynamic>> atender(String hiloId) async {
    final resp = await ApiClient.instance.post('/chat/hilos/$hiloId/atender');
    return Map<String, dynamic>.from(resp.data);
  }

  Future<void> heartbeat(String hiloId) async {
    await ApiClient.instance.post('/chat/hilos/$hiloId/heartbeat');
  }

  Future<void> liberar(String hiloId) async {
    await ApiClient.instance.post('/chat/hilos/$hiloId/liberar');
  }
}
