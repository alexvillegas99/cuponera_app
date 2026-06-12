import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache de lectura persistente en disco para responder offline o mientras
/// llega un fetch fresco (patrón stale-while-revalidate).
///
/// Uso típico:
///
/// ```dart
/// // Al leer:
/// final cached = await CacheService.I.read<List<dynamic>>('promos:tung');
/// // pinto cached si existe...
/// try {
///   final fresh = await http.get(...);
///   await CacheService.I.write('promos:tung', fresh);
///   // repinto con fresh
/// } catch (_) {
///   if (cached == null) rethrow; // no había nada → mostrar empty offline
/// }
/// ```
///
/// El cache NO tiene TTL forzado: se asume "siempre válido" porque el fetch
/// real lo sobreescribe. Si el usuario está offline, lo que tiene es lo
/// último que vio — eso es justamente lo que queremos.
class CacheService {
  CacheService._();
  static final CacheService I = CacheService._();

  static const _prefix = 'cache_v1:';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Llamar una vez en main() para warm-up (no es obligatorio).
  Future<void> init() async {
    await _p;
  }

  /// Lee un valor cacheado. Devuelve null si no hay nada.
  ///
  /// [T] debe ser un tipo JSON: Map, List, String, num, bool. Si el JSON
  /// guardado no encaja con T, devuelve null silenciosamente (no rompe).
  Future<T?> read<T>(String key) async {
    try {
      final prefs = await _p;
      final raw = prefs.getString('$_prefix$key');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is T) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Guarda un valor. [value] debe ser JSON-serializable.
  Future<void> write(String key, Object? value) async {
    try {
      if (value == null) {
        await delete(key);
        return;
      }
      final prefs = await _p;
      await prefs.setString('$_prefix$key', jsonEncode(value));
    } catch (_) {
      // no romper la app por un fallo de cache
    }
  }

  /// Borra una entrada.
  Future<void> delete(String key) async {
    final prefs = await _p;
    await prefs.remove('$_prefix$key');
  }

  /// Borra TODO el cache. Útil al hacer logout completo o cambiar de cuenta.
  Future<void> clear() async {
    final prefs = await _p;
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// ¿Hay al menos una entrada cacheada? Útil para decidir si mostrar
  /// "Sin datos" vs "Modo offline".
  Future<bool> hasAny() async {
    final prefs = await _p;
    return prefs.getKeys().any((k) => k.startsWith(_prefix));
  }
}
