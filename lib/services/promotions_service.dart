// lib/services/promotions_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enjoy/services/core/api_client.dart';

import '../models/promotion_models.dart';
import '../mappers/promotion_mapper.dart';

/// Estado en caché de un "feed" paginado (acumula las páginas traídas).
class PromoFeed {
  final List<Promotion> promos;
  final int page;
  final bool hasMore;
  final int total;
  const PromoFeed({
    required this.promos,
    required this.page,
    required this.hasMore,
    required this.total,
  });
}

class PromotionsService {
  /// 🔹 Trae todas las promos activas (ajusta el endpoint según tu backend)
Future<List<Promotion>> getAllActivePromos({
  List<String>? cityIds,
}) async {
  final Map<String, dynamic> params = {};
  if (cityIds != null && cityIds.isNotEmpty) {
    params['ciudades'] = cityIds.join(',');
  }

  print('[PromotionsService] ➡️ GET /usuarios/por-ciudades params=$params');
  final resp = await ApiClient.instance.get(
    '/usuarios/por-ciudades',
    queryParameters: params.isEmpty ? null : params,
  );

  print('[PromotionsService] ⬅️ Status: ${resp.statusCode}');
  if (resp.statusCode != 200) {
    print('[PromotionsService] ❌ Body: ${resp.data}');
    throw Exception('Error ${resp.statusCode}: ${resp.data}');
  }

  final List data = resp.data as List;
  print('[PromotionsService] ✅ Items: ${data.length}');
  return data
      .map((e) => mapBackendItemToPromotion(e as Map<String, dynamic>))
      .toList();
}
  /// 🔹 Trae TODAS las promos de una provincia (el backend expande a sus ciudades).
  /// Endpoint: /usuarios/por-provincia?provincia=<id>
  Future<List<Promotion>> getByProvincia(String provinciaId) async {
    final resp = await ApiClient.instance.get(
      '/usuarios/por-provincia',
      queryParameters: {'provincia': provinciaId},
    );
    if (resp.statusCode != 200) {
      throw Exception('Error ${resp.statusCode}: ${resp.data}');
    }
    final List data = resp.data as List;
    return data
        .map((e) => mapBackendItemToPromotion(e as Map<String, dynamic>))
        .toList();
  }

  /// 🔹 Trae las promos de VARIAS provincias (merge deduplicado por id).
  Future<List<Promotion>> getByProvincias(List<String> provinciaIds) async {
    final results = await Future.wait(
      provinciaIds.map((id) => getByProvincia(id)),
    );
    final seen = <String>{};
    final out = <Promotion>[];
    for (final list in results) {
      for (final p in list) {
        if (seen.add(p.id)) out.add(p);
      }
    }
    return out;
  }

  /// 🔹 Trae promos filtrando por IDs de ciudades
  /// Tu backend espera: /usuarios/por-ciudades?ciudades=id1,id2,id3
  Future<List<Promotion>> getByCityIds(List<String> ciudadIds) async {
    final joined = ciudadIds.join(',');

    print('[PromotionsService] ➡️ GET /usuarios/por-ciudades?ciudades=$joined');
    final resp = await ApiClient.instance.get(
      '/usuarios/por-ciudades',
      queryParameters: {'ciudades': joined},
    );

    print('[PromotionsService] ⬅️ Status: ${resp.statusCode}');
    if (resp.statusCode != 200) {
      print('[PromotionsService] ❌ Body: ${resp.data}');
      throw Exception('Error ${resp.statusCode}: ${resp.data}');
    }

    final List data = resp.data as List;
    print('[PromotionsService] ✅ Items: ${data.length}');

    return data
        .map((e) => mapBackendItemToPromotion(e as Map<String, dynamic>))
        .toList();
  }

  // ===== Paginación + caché en memoria (endpoint nuevo /usuarios/promos) =====

  /// Caché compartida por firma de filtro. Sobrevive a navegación/tabs.
  /// Se pierde al cerrar la app. Se refresca solo con pull-to-refresh.
  static final Map<String, PromoFeed> _cache = {};

  static String feedSig({
    required List<String> provinciaIds,
    List<String>? ciudadIds,
    String? q,
    bool isToday = false,
    bool isFlash = false,
    List<String>? localIds,
    bool cercania = false,
  }) {
    final prov = ([...provinciaIds]..sort()).join('.');
    final ciu = ([...(ciudadIds ?? const [])]..sort()).join('.');
    final loc = localIds == null ? '*' : ([...localIds]..sort()).join('.');
    final query = (q ?? '').trim().toLowerCase();
    return 'p=$prov|c=$ciu|q=$query|t=$isToday|f=$isFlash|l=$loc|d=$cercania';
  }

  PromoFeed? cached(String sig) => _cache[sig];

  void clearCache([String? sig]) {
    if (sig == null) {
      _cache.clear();
    } else {
      _cache.remove(sig);
    }
  }

  // ===== Persistencia en disco (offline) =====

  static String _sigKey(String sig) =>
      'promos_cache_${sig.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}';

  Future<void> _persistFeed(String sig, List rawList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sigKey(sig), jsonEncode(rawList));
    } catch (_) {}
  }

  Future<PromoFeed?> _loadPersistedFeed(String sig) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_sigKey(sig));
      if (str == null) return null;
      final decoded = jsonDecode(str);
      if (decoded is! List) return null;
      final promos = decoded
          .whereType<Map>()
          .map((e) => mapBackendItemToPromotion(Map<String, dynamic>.from(e)))
          .toList();
      return PromoFeed(
        promos: promos,
        page: 1,
        hasMore: false,
        total: promos.length,
      );
    } catch (_) {
      return null;
    }
  }

  Future<PromoFeed> _fetchPage({
    required List<String> provinciaIds,
    List<String>? ciudadIds,
    String? q,
    bool isToday = false,
    bool isFlash = false,
    List<String>? localIds,
    double? lat,
    double? lng,
    required int page,
    int limit = 30,
    String? persistSig,
  }) async {
    final qp = <String, dynamic>{
      'provincias': provinciaIds.join(','),
      'page': page,
      'limit': limit,
    };
    if (ciudadIds != null && ciudadIds.isNotEmpty) {
      qp['ciudades'] = ciudadIds.join(',');
    }
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
    if (isToday) qp['isToday'] = 'true';
    if (isFlash) qp['isFlash'] = 'true';
    if (localIds != null) qp['localIds'] = localIds.join(',');
    if (lat != null && lng != null) {
      qp['lat'] = lat;
      qp['lng'] = lng;
    }

    final resp =
        await ApiClient.instance.get('/usuarios/promos', queryParameters: qp);
    final body = resp.data as Map<String, dynamic>;
    final rawList = (body['data'] as List);
    // Persistir el feed en disco (offline) — solo la 1ª página.
    if (persistSig != null) {
      await _persistFeed(persistSig, rawList);
    }
    final promos = rawList
        .map((e) => mapBackendItemToPromotion(e as Map<String, dynamic>))
        .toList();
    return PromoFeed(
      promos: promos,
      page: (body['page'] ?? page) as int,
      hasMore: body['hasMore'] == true,
      total: (body['total'] ?? promos.length) as int,
    );
  }

  /// Carga la primera página del feed. Si ya está en caché y no se fuerza,
  /// devuelve lo cacheado sin pegarle al backend.
  Future<PromoFeed> loadFirst({
    required List<String> provinciaIds,
    List<String>? ciudadIds,
    String? q,
    bool isToday = false,
    bool isFlash = false,
    List<String>? localIds,
    double? lat,
    double? lng,
    int limit = 30,
    bool force = false,
  }) async {
    final sig = feedSig(
      provinciaIds: provinciaIds,
      ciudadIds: ciudadIds,
      q: q,
      isToday: isToday,
      isFlash: isFlash,
      localIds: localIds,
      cercania: lat != null && lng != null,
    );
    if (!force && _cache.containsKey(sig)) return _cache[sig]!;

    try {
      final feed = await _fetchPage(
        provinciaIds: provinciaIds,
        ciudadIds: ciudadIds,
        q: q,
        isToday: isToday,
        isFlash: isFlash,
        localIds: localIds,
        lat: lat,
        lng: lng,
        page: 1,
        limit: limit,
        persistSig: sig,
      );
      _cache[sig] = feed;
      return feed;
    } catch (e) {
      // Sin conexión / error → feed cacheado en disco (offline).
      final cached = await _loadPersistedFeed(sig);
      if (cached != null) {
        _cache[sig] = cached;
        return cached;
      }
      rethrow;
    }
  }

  /// Carga la siguiente página y la agrega a la caché. Devuelve el feed
  /// acumulado (o el mismo si no hay más).
  Future<PromoFeed> loadMore({
    required List<String> provinciaIds,
    List<String>? ciudadIds,
    String? q,
    bool isToday = false,
    bool isFlash = false,
    List<String>? localIds,
    double? lat,
    double? lng,
    int limit = 30,
  }) async {
    final sig = feedSig(
      provinciaIds: provinciaIds,
      ciudadIds: ciudadIds,
      q: q,
      isToday: isToday,
      isFlash: isFlash,
      localIds: localIds,
      cercania: lat != null && lng != null,
    );
    final current = _cache[sig];
    if (current == null || !current.hasMore) return current ?? const PromoFeed(promos: [], page: 1, hasMore: false, total: 0);

    final PromoFeed next;
    try {
      next = await _fetchPage(
        provinciaIds: provinciaIds,
        ciudadIds: ciudadIds,
        q: q,
        isToday: isToday,
        isFlash: isFlash,
        localIds: localIds,
        lat: lat,
        lng: lng,
        page: current.page + 1,
        limit: limit,
      );
    } catch (_) {
      // Sin red durante un loadMore: devolvemos lo que ya tenemos,
      // marcando hasMore=false para que el infinite-scroll deje de pedir
      // hasta que vuelva la conexión y el usuario haga refresh.
      return PromoFeed(
        promos: current.promos,
        page: current.page,
        hasMore: false,
        total: current.total,
      );
    }
    // Append deduplicado por id.
    final seen = current.promos.map((p) => p.id).toSet();
    final merged = [
      ...current.promos,
      ...next.promos.where((p) => seen.add(p.id)),
    ];
    final feed = PromoFeed(
      promos: merged,
      page: next.page,
      hasMore: next.hasMore,
      total: next.total,
    );
    _cache[sig] = feed;
    return feed;
  }
}
