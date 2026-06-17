import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enjoy/mappers/cuponera.dart';
import 'package:enjoy/services/categorias_service.dart';
import 'package:enjoy/services/ciudades_service.dart';
import 'package:enjoy/services/comercios_service.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:enjoy/services/informacion_perfil_cliente_service.dart';
import 'package:enjoy/services/promociones_flash_service.dart';
import 'package:enjoy/services/promotions_service.dart';
import 'package:enjoy/services/versiones_service.dart';

const _kSelectedCityIdsKey = 'selected_city_ids_v1';
const _kSelectedProvinciasKey = 'selected_provincia_ids_v1';

/// Descarga en segundo plano TODO lo que el cliente va a querer ver offline:
/// catálogos, promos de su provincia, cuponeras, perfil, historial.
///
/// Es totalmente best-effort: cada paso falla independiente sin tirar abajo
/// los demás. Se dispara tras un login exitoso (`fire-and-forget`) y NO
/// bloquea la navegación al home.
class PrefetchService {
  PrefetchService._();
  static final PrefetchService I = PrefetchService._();

  /// Si ya hay un prefetch corriendo para este cliente, no arrancamos otro.
  static String? _ejecutandoPara;

  /// Cuántas páginas extra del feed cargar para uso offline (cada una ~30
  /// items). 3 páginas ≈ 90 promos cacheadas. Subir esto cuesta MB en disco
  /// y datos móviles — 3 es un buen balance.
  static const int _kPaginasExtraFeed = 2;

  /// Lanza el prefetch del cliente con id [clienteId]. Si ya estaba corriendo
  /// para ese mismo cliente, ignora la llamada (evita doble trabajo si el
  /// usuario sale y entra rápido).
  Future<void> warmupCliente(String clienteId) async {
    if (clienteId.isEmpty) return;
    if (_ejecutandoPara == clienteId) return;
    _ejecutandoPara = clienteId;
    final inicio = DateTime.now();
    debugPrint('🔥 [Prefetch] inicio cliente=$clienteId');

    try {
      // 1) Catálogos territoriales y de categorías — los reusan muchas
      //    pantallas (registro, filtros, mapa, etc.).
      await _ejecutarPaso(
        'catálogos',
        () => Future.wait([
          CiudadesService().getProvincias().then((_) {}).catchError((_) {}),
          CiudadesService().getParaPromos().then((_) {}).catchError((_) {}),
          CategoriasService().getActivas().then((_) {}).catchError((_) {}),
          VersionesService.listarActivasPaginado(force: true)
              .then((_) {})
              .catchError((_) {}),
        ]),
      );

      // 2) Perfil del cliente — se cachea para mostrar avatar/nombre offline.
      await _ejecutarPaso(
        'perfil',
        () => InformacionPerfilClienteService().fetch(),
      );

      // 3) Sus cuponeras (lista + cada detalle).
      final cupones = await _ejecutarPaso<List<Cuponera>>(
        'cuponeras del cliente',
        () => CuponesService().listarPorCliente(clienteId, soloActivas: true),
      );
      final cuponesList = cupones ?? const <Cuponera>[];
      if (cuponesList.isNotEmpty) {
        // Detalle por cupón en paralelo, en lotes para no saturar el back.
        await _enLotes<Cuponera>(cuponesList, lote: 3, fn: (c) async {
          final id = c.id.toString();
          if (id.isEmpty) return;
          try {
            await CuponesService().obtenerDetallePorCupon(id);
          } catch (_) {}
        });
      }

      // 4) Locales donde el cliente tiene cupón disponible para canjear
      //    — el listado del filtro "solo con cupón" del feed.
      await _ejecutarPaso(
        'locales con cupón disponible',
        () => CuponesService().localesDisponibles(clienteId),
      );

      // 5) Historial de canjes del cliente.
      await _ejecutarPaso(
        'historial de canjes',
        () => HistoricoCuponService().obtenerPorUsuario(clienteId),
      );

      // 6) Feed de promociones de su ubicación (varias páginas para tener
      //    "buffer" offline).
      final ubicacion = await _leerUbicacionGuardada();
      if (ubicacion.provincias.isNotEmpty) {
        await _ejecutarPaso(
          'feed promociones',
          () => _prefetchFeed(ubicacion),
        );
      }

      // 7) Promociones flash actuales para esa ubicación.
      if (ubicacion.provincias.isNotEmpty) {
        await _ejecutarPaso(
          'feed flash',
          () => PromocionesFlashService().feed(
            provincia: ubicacion.provincias.first,
            ciudades: ubicacion.ciudades.isEmpty ? null : ubicacion.ciudades,
            page: 1,
            limit: 30,
          ),
        );
      }

      // 8) Detalle de los locales de la cuponera del cliente — para que abra
      //    cualquier local desde su cuponera sin pegarle al back.
      if (cuponesList.isNotEmpty) {
        final localIds = await _idsLocalesDeCupones(cuponesList);
        await _enLotes<String>(
          localIds.toList(),
          lote: 4,
          fn: (id) async {
            try {
              await ComerciosService().obtenerInformacionComercioMini(id);
            } catch (_) {}
          },
        );
      }

      final ms = DateTime.now().difference(inicio).inMilliseconds;
      debugPrint('🔥 [Prefetch] completo cliente=$clienteId en ${ms}ms');
    } catch (e, st) {
      debugPrint('🔥 [Prefetch] error: $e\n$st');
    } finally {
      _ejecutandoPara = null;
    }
  }

  Future<T?> _ejecutarPaso<T>(
    String etiqueta,
    Future<T> Function() fn,
  ) async {
    try {
      final r = await fn();
      debugPrint('🔥 [Prefetch] ✓ $etiqueta');
      return r;
    } catch (e) {
      debugPrint('🔥 [Prefetch] ✗ $etiqueta: $e');
      return null;
    }
  }

  /// Itera [items] aplicando [fn] en lotes de [lote] para no abrir
  /// 100 conexiones HTTP al mismo tiempo.
  Future<void> _enLotes<T>(
    List<T> items, {
    required int lote,
    required Future<void> Function(T) fn,
  }) async {
    for (var i = 0; i < items.length; i += lote) {
      final fin = (i + lote).clamp(0, items.length);
      await Future.wait(items.sublist(i, fin).map(fn));
    }
  }

  Future<_Ubicacion> _leerUbicacionGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final provs = prefs.getStringList(_kSelectedProvinciasKey) ?? const [];
    final ciudades = prefs.getStringList(_kSelectedCityIdsKey) ?? const [];
    return _Ubicacion(provincias: provs, ciudades: ciudades);
  }

  Future<void> _prefetchFeed(_Ubicacion u) async {
    final svc = PromotionsService();
    await svc.loadFirst(
      provinciaIds: u.provincias,
      ciudadIds: u.ciudades.isEmpty ? null : u.ciudades,
      isToday: false,
      force: true,
    );
    for (var i = 0; i < _kPaginasExtraFeed; i++) {
      try {
        final feed = await svc.loadMore(
          provinciaIds: u.provincias,
          ciudadIds: u.ciudades.isEmpty ? null : u.ciudades,
        );
        if (!feed.hasMore) break;
      } catch (_) {
        break;
      }
    }
    // Y también el feed "hoy" para que la pestaña Hoy del home cargue offline.
    try {
      await svc.loadFirst(
        provinciaIds: u.provincias,
        ciudadIds: u.ciudades.isEmpty ? null : u.ciudades,
        isToday: true,
        force: true,
      );
    } catch (_) {}
  }

  /// Recolecta los `usuarioId` (= localId) de los locales presentes en los
  /// detalles de las cuponeras del cliente.
  Future<Set<String>> _idsLocalesDeCupones(List<Cuponera> cupones) async {
    final ids = <String>{};
    for (final c in cupones) {
      final id = c.id.toString();
      if (id.isEmpty) continue;
      try {
        final detalle = await CuponesService().obtenerDetallePorCupon(id);
        for (final l in detalle.lugaresScaneados) {
          if (l.usuarioId.isNotEmpty) ids.add(l.usuarioId);
        }
        for (final l in detalle.lugaresSinScannear) {
          if (l.usuarioId.isNotEmpty) ids.add(l.usuarioId);
        }
      } catch (_) {}
    }
    return ids;
  }
}

class _Ubicacion {
  final List<String> provincias;
  final List<String> ciudades;
  const _Ubicacion({required this.provincias, required this.ciudades});
}
