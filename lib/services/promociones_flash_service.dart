// lib/services/promociones_flash_service.dart
import 'package:enjoy/services/core/api_client.dart';

/// Servicio de Promociones Flash (admin-local, cliente y canje staff).
class PromocionesFlashService {
  // ── Admin-local ────────────────────────────────────────────────────────────

  /// Crea una promoción flash. POST /promociones-flash
  Future<Map<String, dynamic>> crear(Map<String, dynamic> data) async {
    final resp = await ApiClient.instance.post('/promociones-flash', data: data);
    return Map<String, dynamic>.from(resp.data);
  }

  /// Lista las promos del local. GET /promociones-flash/mias
  /// Devuelve { data: [...], activas, max }.
  Future<Map<String, dynamic>> mias({String? estado}) async {
    final resp = await ApiClient.instance.get(
      '/promociones-flash/mias',
      queryParameters: estado != null ? {'estado': estado} : null,
    );
    return Map<String, dynamic>.from(resp.data);
  }

  /// Actualiza / pausa. PATCH /promociones-flash/:id
  Future<Map<String, dynamic>> actualizar(
    String id,
    Map<String, dynamic> data,
  ) async {
    final resp =
        await ApiClient.instance.patch('/promociones-flash/$id', data: data);
    return Map<String, dynamic>.from(resp.data);
  }

  /// Elimina. DELETE /promociones-flash/:id
  Future<void> eliminar(String id) async {
    await ApiClient.instance.delete('/promociones-flash/$id');
  }

  // ── Cliente ──────────────────────────────────────────────────────────────────

  /// Feed por ciudad(es) o provincia. GET /promociones-flash
  Future<Map<String, dynamic>> feed({
    List<String>? ciudades,
    String? provincia,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (ciudades != null && ciudades.isNotEmpty) {
      params['ciudades'] = ciudades.join(',');
    } else if (provincia != null && provincia.isNotEmpty) {
      params['provincia'] = provincia;
    }
    final resp = await ApiClient.instance
        .get('/promociones-flash', queryParameters: params);
    return Map<String, dynamic>.from(resp.data);
  }

  /// Detalle (suma una vista). GET /promociones-flash/:id
  Future<Map<String, dynamic>> detalle(String id) async {
    final resp = await ApiClient.instance.get('/promociones-flash/$id');
    return Map<String, dynamic>.from(resp.data);
  }

  /// Cliente: usar la promo → devuelve { qrData, titulo }. POST /:id/usar
  Future<Map<String, dynamic>> usar(String id) async {
    final resp = await ApiClient.instance.post('/promociones-flash/$id/usar');
    return Map<String, dynamic>.from(resp.data);
  }

  // ── Canje (staff escanea) ────────────────────────────────────────────────────

  /// Valida el QR de canje. POST /promociones-flash/validar
  Future<Map<String, dynamic>> validar(String qrData) async {
    final resp = await ApiClient.instance
        .post('/promociones-flash/validar', data: {'qrData': qrData});
    return Map<String, dynamic>.from(resp.data);
  }
}
