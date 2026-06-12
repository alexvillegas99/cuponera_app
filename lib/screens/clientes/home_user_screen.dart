import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:enjoy/mappers/cuponera.dart';
import 'package:enjoy/models/categoria.dart';
import 'package:enjoy/models/ciudad.dart';
import 'package:enjoy/models/provincia.dart';
import 'package:enjoy/screens/clientes/cuponeras_screen_light.dart';
import 'package:enjoy/screens/clientes/notificaciones_screen.dart';
import 'package:enjoy/screens/clientes/promociones_flash_screen.dart';
import 'package:enjoy/screens/clientes/promos_hoy_screen.dart';
import 'package:enjoy/services/campanas_service.dart';
import 'package:enjoy/screens/clientes/favorites_screen_light.dart';
import 'package:enjoy/screens/clientes/profile_screen_light.dart';
import 'package:enjoy/screens/clientes/search_screen_light.dart';
import 'package:enjoy/screens/clientes/detalle_cupon.dart';
import 'package:enjoy/screens/clientes/comercio_detalle_mini_screen.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/categorias_service.dart';
import 'package:enjoy/services/ciudades_service.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/services/promotions_service.dart';
import 'package:enjoy/screens/clientes/detalle_version_screen.dart';
import 'package:enjoy/screens/clientes/mapa_version_screen.dart';
import 'package:enjoy/services/versiones_service.dart';
import 'package:enjoy/state/favorites_store.dart';
import 'package:enjoy/utilities/categoria_icons.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/promotion_models.dart';
import '../../widgets/city_filter_icon.dart';
import '../../widgets/province_cities_picker.dart';

const _kSelectedCityIdsKey = 'selected_city_ids_v1';
const _kSelectedProvinciasKey = 'selected_provincia_ids_v1';
const _kNotifPromos = 'notif_promos_v1';
const _kCityTopicsPrefs = 'notif_city_topics_v2';
const _kFavCuponeraKey = 'fav_cuponera_id_v1';

class PromotionsHomeScreen extends StatefulWidget {
  final bool guestMode;
  const PromotionsHomeScreen({super.key, this.guestMode = false});

  @override
  State<PromotionsHomeScreen> createState() => _PromotionsHomeScreenState();
}

class _PromotionsHomeScreenState extends State<PromotionsHomeScreen>
    with SingleTickerProviderStateMixin {
  // ===== Helpers de log =====
  void _log(String msg) => debugPrint('[CityPrefs] $msg');

  // ===== Servicios =====
  final authService = AuthService();
  final _ciudadesService = CiudadesService();
  final _catService = CategoriasService();
  final _promoService = PromotionsService();
  FirebaseMessaging? _fm;

  // ===== Estado UI =====
  late final TabController _tabController;
  int _bottomIndex = 0;

  // ===== Cat/City =====
  List<Categoria> _categorias = [];
  bool _catsLoading = true;
  String? _catsError;

  List<Ciudad> _ciudades = [];
  bool _citiesLoading = true;
  String? _citiesError;

  // Provincia seleccionada (filtra las ciudades disponibles)
  List<Provincia> _provincias = [];
  final Set<String> _selectedProvinciaIds = {};

  // Ubicación del cliente (para calcular distancia a cada local)
  double? _userLat;
  double? _userLng;

  // IDs seleccionados (del backend)
  final Set<String> _selectedCityIds = {};

  // Mapeos nombre<->id para el picker
  final Map<String, String> _cityIdByName = {};
  final Map<String, String> _cityNameById = {};

  List<String> get _cityNames => _ciudades.map((c) => c.nombre).toList();
  Set<String> get _selectedCityNames =>
      _selectedCityIds.map((id) => _cityNameById[id]!).toSet();

  // ===== Promos & filtros =====
  List<Promotion> _allPromos = [];
  bool _loadingPromos = true;
  String? _promosError;

  // ===== Promos de hoy (carrusel destacado) =====
  List<Promotion> _promosHoy = [];
  bool _loadingHoy = false;
  /// Tab interno del bloque destacado: 'hoy' | 'flash'
  String _destacadoTab = 'hoy';

  String _query = '';
  final Set<String> _selectedCats = {};

  // ===== Filtros avanzados (bottom sheet) =====
  bool _ordenarCercania = false;
  bool _soloConCupon = false;
  String _ordenNombre = 'none'; // 'none' | 'asc' | 'desc'
  bool _cargandoDisponibles = false;
  final Set<String> _localesConCupon = {};

  bool get _filtrosActivos =>
      _ordenarCercania ||
      _soloConCupon ||
      _selectedCiudadIds.isNotEmpty ||
      _ordenNombre != 'none';

  // ===== Paginación (infinite scroll) =====
  bool _hasMore = false;
  bool _loadingMore = false;
  final Set<String> _selectedCiudadIds = {};
  List<Ciudad> _ciudadesFiltro = [];
  Timer? _searchDebounce;

  // ===== Cuponeras =====
  List<Cuponera> _cuponeras = [];
  bool _loadingCuponeras = true;
  String? _cuponerasError;

  // Cuponera destacada en el home (favorita del cliente) + caché de nº de
  // locales por versión (para mostrar "N locales disponibles").
  String? _favCuponeraId;
  final Map<String, int> _localesCountByVersion = {};

  // ===== Notificaciones por ciudad (topics) =====
  final RegExp _topicRegex = RegExp(r'^[A-Za-z0-9\-_.~%]+$');
  bool _isValidTopic(String t) =>
      t.isNotEmpty && t.length <= 900 && _topicRegex.hasMatch(t);

  String _slug(String input) {
    final lower = input.trim().toLowerCase();
    final s = lower
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9\-_.~%]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-\$'), '');
    return s;
  }

  String _cityTopicForId(String cityId) {
    final rawName = _cityNameById[cityId];
    final base = rawName != null ? _slug(rawName) : _slug(cityId);
    final safe = (base.isEmpty ? cityId.toLowerCase() : base);
    return safe;
  }

  Future<Set<String>> _loadTopicsSet() async {
    final prefs = await SharedPreferences.getInstance();

    // correcto (List<String>)
    final list = prefs.getStringList(_kCityTopicsPrefs);
    if (list != null) {
      return list.where((e) => e.trim().isNotEmpty).toSet();
    }

    // migración desde String accidental
    final str = prefs.getString(_kCityTopicsPrefs);
    if (str == null || str.isEmpty) return <String>{};

    try {
      final decoded = jsonDecode(str);
      if (decoded is List) {
        final migrated = decoded
            .map((e) => (e ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet();
        await prefs.setStringList(_kCityTopicsPrefs, migrated.toList());
        return migrated;
      }
      if (decoded is String) {
        final migrated = decoded
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
        await prefs.setStringList(_kCityTopicsPrefs, migrated.toList());
        return migrated;
      }
    } catch (_) {
      final migrated = str
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      await prefs.setStringList(_kCityTopicsPrefs, migrated.toList());
      return migrated;
    }

    return <String>{};
  }

  Future<void> _saveTopicsSet(Set<String> topics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kCityTopicsPrefs, topics.toList());
  }

 Future<void> _syncCityTopics() async {
  if (Platform.isIOS || _fm == null) return; // 🔴 BLOQUEO TOTAL

  final prefs = await SharedPreferences.getInstance();
  final promosOn = prefs.getBool(_kNotifPromos) ?? true;

  final current = await _loadTopicsSet();
  final currentValid = current.where(_isValidTopic).toSet();

  if (!promosOn || _selectedCityIds.isEmpty) {
    for (final t in currentValid) {
      await _fm!.unsubscribeFromTopic(t);
    }
    await _saveTopicsSet(<String>{});
    return;
  }

  final desiredRaw = _selectedCityIds.map(_cityTopicForId).toSet();
  final desired = desiredRaw.where(_isValidTopic).toSet();

  final toSub = desired.difference(currentValid);
  final toUnsub = currentValid.difference(desired);

  final s = await _fm!.getNotificationSettings();

  if (s.authorizationStatus != AuthorizationStatus.authorized &&
      s.authorizationStatus != AuthorizationStatus.provisional) {
    final r = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final ok =
        r.authorizationStatus == AuthorizationStatus.authorized ||
        r.authorizationStatus == AuthorizationStatus.provisional;

    if (!ok) {
      await _saveTopicsSet(desired);
      return;
    }
  }

  for (final t in toSub) {
    await _fm!.subscribeToTopic(t);
  }
  for (final t in toUnsub) {
    await _fm!.unsubscribeFromTopic(t);
  }

  await _saveTopicsSet(desired);
}
  // ===== Persistencia de selección de provincia + ciudades =====
  Future<void> _saveSelectedCityIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _kSelectedProvinciasKey, _selectedProvinciaIds.toList());
  }

  Future<void> _restoreSavedCitySelection() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kSelectedProvinciasKey) ?? const [];
    if (saved.isEmpty) return;
    setState(() {
      _selectedProvinciaIds
        ..clear()
        ..addAll(saved);
    });
    _log('STATE after RESTORE -> $_selectedProvinciaIds');
  }

  // ===== Orquestación =====
  @override
  void initState() {
    super.initState();
    if (!Platform.isIOS) {
    _fm = FirebaseMessaging.instance;
  }
    // Solo "Todas" (Hoy/Flash deshabilitadas temporalmente) → 1 tab.
    _tabController = TabController(length: 1, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initScreen();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Cada tab (Todas/Hoy/Flash) es un feed paginado server-side propio.
    _loadPromosByCities();
  }

  Future<void> _initScreen() async {
    try {
      await _loadCategorias();
      await _loadProvincias();
      await _restoreSavedCitySelection();
      await _syncCityTopics();
      await _loadPromosByCities();
      _loadUserLocation(); // best-effort, no bloquea
      if (!widget.guestMode) {
        await _loadCuponeras();
        await _initFavoritesOnce();
      }
    } catch (_) {}
  }

  Future<void> _loadProvincias() async {
    try {
      _provincias = await _ciudadesService.getProvincias();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// Obtiene la ubicación del cliente (best-effort) para calcular distancias.
  Future<void> _loadUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      });
    } catch (_) {}
  }

  bool _didInitFavs = false;
  Future<void> _initFavoritesOnce() async {
    if (_didInitFavs) return;
    _didInitFavs = true;
    try {
      final usuario = await authService.getUser();
      if (!mounted) return;
      final id = usuario?['_id'] as String?;
      if (id != null) {
        await context.read<FavoritesStore>().init(id);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  // ===== Cargas =====
  Future<void> _loadCategorias() async {
    try {
      final cats = await _catService.getActivas();
      if (mounted) {
        setState(() {
          _categorias = cats;
          _catsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _catsError = e.toString();
          _catsLoading = false;
        });
      }
    }
  }

  /// Carga la primera página del feed según el tab activo y los filtros.
  /// [force] = pull-to-refresh (ignora la caché).
  Future<void> _loadPromosByCities({bool force = false}) async {
    if (_selectedProvinciaIds.isEmpty) {
      if (mounted) {
        setState(() {
          _allPromos = [];
          _promosError = null;
          _loadingPromos = false;
          _hasMore = false;
        });
      }
      return;
    }

    try {
      setState(() => _loadingPromos = true);
      final idx = _tabController.index; // 0 Todas · 1 Hoy · 2 Flash
      final feed = await _promoService.loadFirst(
        provinciaIds: _selectedProvinciaIds.toList(),
        ciudadIds: _selectedCiudadIds.isEmpty ? null : _selectedCiudadIds.toList(),
        q: _query.isEmpty ? null : _query,
        isToday: idx == 1,
        isFlash: idx == 2,
        localIds: _soloConCupon ? _localesConCupon.toList() : null,
        lat: _ordenarCercania ? _userLat : null,
        lng: _ordenarCercania ? _userLng : null,
        force: force,
      );
      if (mounted) {
        setState(() {
          _allPromos = feed.promos;
          _hasMore = feed.hasMore;
          _promosError = null;
          _loadingPromos = false;
        });
      }
      // Cargar en paralelo el feed "Hoy" para el carrusel destacado.
      _loadPromosHoy();
      _debugIds();
    } catch (e) {
      if (mounted) {
        setState(() {
          _promosError = e.toString();
          _loadingPromos = false;
        });
      }
    }
  }

  /// Carrusel "Promos de hoy": fetch independiente del feed principal,
  /// trae las promos activas hoy (mix flash + normales destacadas).
  Future<void> _loadPromosHoy() async {
    if (_selectedProvinciaIds.isEmpty) {
      if (mounted) setState(() => _promosHoy = []);
      return;
    }
    if (_loadingHoy) return;
    setState(() => _loadingHoy = true);
    try {
      final feed = await _promoService.loadFirst(
        provinciaIds: _selectedProvinciaIds.toList(),
        ciudadIds: _selectedCiudadIds.isEmpty ? null : _selectedCiudadIds.toList(),
        isToday: true,
        force: false,
      );
      if (mounted) {
        setState(() {
          _promosHoy = feed.promos.take(12).toList();
          _loadingHoy = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHoy = false);
    }
  }

  /// Carga la siguiente página (infinite scroll) y la agrega.
  Future<void> _loadMoreFeed() async {
    if (_loadingMore || !_hasMore || _selectedProvinciaIds.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final idx = _tabController.index;
      final feed = await _promoService.loadMore(
        provinciaIds: _selectedProvinciaIds.toList(),
        ciudadIds: _selectedCiudadIds.isEmpty ? null : _selectedCiudadIds.toList(),
        q: _query.isEmpty ? null : _query,
        isToday: idx == 1,
        isFlash: idx == 2,
        localIds: _soloConCupon ? _localesConCupon.toList() : null,
        lat: _ordenarCercania ? _userLat : null,
        lng: _ordenarCercania ? _userLng : null,
      );
      if (mounted) {
        setState(() {
          _allPromos = feed.promos;
          _hasMore = feed.hasMore;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Widget _cityChip(String label, bool selected, VoidCallback onTap) {
    return Pill(
      label,
      variant: selected ? PillVariant.orange : PillVariant.glass,
      onTap: onTap,
    );
  }

  /// Tarjeta de promoción (estilo mockup) construida desde una [Promotion].
  Widget _promoCard(Promotion p, FavoritesStore favs) {
    final dist = _distanciaA(p);
    final distStr =
        dist.isFinite ? '${(dist / 1000).toStringAsFixed(1)} km' : null;
    final cat = p.categories.isNotEmpty ? p.categories.first : p.city;
    final subtitle = [distStr, cat]
        .where((e) => e != null && e.isNotEmpty)
        .join(' · ');
    final title = p.placeName.isNotEmpty ? p.placeName : p.title;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: PromoCard(
        title: title,
        subtitle: subtitle.isEmpty ? p.title : subtitle,
        imageUrl: p.coverUrl,
        discount: p.isTwoForOne ? '2x1' : null,
        tieneFlash: p.tieneFlash,
        isFavorite: favs.isFav(p.id),
        onFavorite: () => context.read<FavoritesStore>().toggle(p.id),
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComercioDetalleMiniScreen(usuarioId: p.id),
            ),
          );
        },
      ),
    );
  }

  /// Abre la pantalla de Buscar (pestaña del navbar).
  void _openBuscar() {
    final favs = context.read<FavoritesStore>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnjoyScaffold(
          padding: EdgeInsets.zero,
          appBar: const EnjoyAppBar(title: 'Buscar'),
          body: SearchScreenLight(
            all: _allPromos,
            isFavorite: (p) => favs.isFav(p.id),
            onFavorite: (p) => context.read<FavoritesStore>().toggle(p.id),
          ),
        ),
      ),
    );
  }

  /// Abre el perfil (pestaña del navbar).
  void _openPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreenLight()),
    );
  }


  Future<void> _loadCuponeras() async {
    try {
      final usuario = await authService.getUser();
      final clienteId = usuario?['_id'] as String?;
      if (clienteId == null) {
        setState(() {
          _cuponerasError = 'No hay clienteId';
          _loadingCuponeras = false;
        });
        return;
      }

      final list = await CuponesService().listarPorClientePaginado(
        clienteId,
        soloActivas: true,
      );
      setState(() {
        _cuponeras = list;
        _loadingCuponeras = false;
      });
      await _loadFavCuponera();
      _ensureFeaturedLocalesCount();
    } catch (e) {
      setState(() {
        _cuponerasError = e.toString();
        _loadingCuponeras = false;
      });
    }
  }

  /// Cuponera destacada en el home: la favorita del cliente o la primera.
  Cuponera? get _featuredCuponera {
    if (_cuponeras.isEmpty) return null;
    if (_favCuponeraId != null) {
      for (final c in _cuponeras) {
        if (c.id == _favCuponeraId) return c;
      }
    }
    return _cuponeras.first;
  }

  Future<void> _loadFavCuponera() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kFavCuponeraKey);
    if (saved != null && _cuponeras.any((c) => c.id == saved)) {
      if (mounted) setState(() => _favCuponeraId = saved);
    }
  }

  /// Carga (best-effort) el nº de locales de la versión de la cuponera
  /// destacada para mostrar "N locales disponibles".
  Future<void> _ensureFeaturedLocalesCount() async {
    final vid = _featuredCuponera?.versionId;
    if (vid == null || vid.isEmpty || _localesCountByVersion.containsKey(vid)) {
      return;
    }
    try {
      final locales = await VersionesService.listarLocales(vid);
      if (mounted) {
        setState(() => _localesCountByVersion[vid] = locales.length);
      }
    } catch (_) {}
  }

  /// Abre el detalle de una cuponera específica.
  void _openCuponera(Cuponera c) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CuponDetalleScreen(cuponId: c.id)),
    );
  }

  /// Permite elegir qué membresía se destaca en el inicio (si hay varias).
  Future<void> _pickFeaturedCuponera() async {
    final ec = context.ec;
    final currentId = _favCuponeraId ?? _cuponeras.first.id;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ec.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ec.strokeStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Tu membresía destacada',
                  style: EnjoyTheme.heading(
                      size: 17, weight: FontWeight.w800, color: ec.text)),
              const SizedBox(height: 4),
              Text('Elige cuál se muestra en el inicio.',
                  style: EnjoyTheme.body(size: 13, color: ec.textMute)),
              const SizedBox(height: 14),
              ..._cuponeras.map((c) {
                final selected = currentId == c.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListRowTile(
                    leading: IconBox(Icons.local_activity_rounded,
                        accent: selected),
                    title: c.nombre,
                    subtitle: 'Nº ${c.secuencial}',
                    trailing: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? ec.orange : ec.textMute,
                    ),
                    onTap: () => Navigator.pop(context, c.id),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFavCuponeraKey, chosen);
      if (mounted) {
        setState(() => _favCuponeraId = chosen);
        _ensureFeaturedLocalesCount();
      }
    }
  }

  void _debugIds() {
    for (final p in _allPromos.take(5)) {
      debugPrint(
        '[PROMO] title="${p.title}" id=${p.id} detailId=${p.detailId}',
      );
    }
  }

  // ===== Aplicadores =====
  Future<void> _aplicarProvincias(Set<String> ids) async {
    setState(() {
      _selectedProvinciaIds
        ..clear()
        ..addAll(ids);
    });
    await _saveSelectedCityIds();
    await _loadPromosByCities();
  }

  void _toggleCat(String cat) {
    setState(
      () => _selectedCats.contains(cat)
          ? _selectedCats.remove(cat)
          : _selectedCats.add(cat),
    );
  }

  /// Abre el selector multi-provincia. Devuelve los ids elegidos o null.
  Future<Set<String>?> _pickProvincias() async {
    return showProvincePicker(
      context,
      provincias: _provincias,
      initialIds: {..._selectedProvinciaIds},
    );
  }

  // ===== Filtros en memoria =====
  List<Promotion> _onlyToday(List<Promotion> input) {
    final today = DateTime.now();
    final filtered = <Promotion>[];
    for (final p in input) {
      if (p.appliesTodaySimple(today)) filtered.add(p);
    }
    return filtered;
  }

  IconData _iconFor(String? icon) => iconForCategoria(icon);

  List<Promotion> _applyFilters(List<Promotion> input) {
    List<Promotion> list = input;

    // Las promos ya vienen filtradas por provincia(s) desde el backend.

    // 🔹 Búsqueda de texto
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((p) {
        final haystack =
            '${p.title} ${p.placeName} ${p.description} '
                    '${p.categories.join(" ")} ${p.tags.join(" ")}'
                .toLowerCase();
        return haystack.contains(q);
      }).toList();
    }

    // 🔹 Categorías + 2x1
    if (_selectedCats.isNotEmpty) {
      list = list.where((p) {
        if (_selectedCats.contains('2x1') && !p.isTwoForOne) return false;
        final sel = _selectedCats.difference({'2x1'});
        if (sel.isEmpty) return true;
        final promoCatsLower = p.categories.map((e) => e.toLowerCase()).toSet();
        final selLower = sel.map((e) => e.toLowerCase()).toSet();
        return promoCatsLower.intersection(selLower).isNotEmpty;
      }).toList();
    }

    // Nota: "solo con cupón disponible" y "orden por cercanía" ahora se
    // resuelven server-side (params localIds / lat-lng del endpoint paginado).

    // 🔹 Orden por nombre (A-Z / Z-A) — client-side sobre lo cargado.
    if (_ordenNombre != 'none') {
      String nombre(Promotion p) =>
          (p.placeName.isNotEmpty ? p.placeName : p.title).toLowerCase();
      list = List<Promotion>.from(list)
        ..sort((a, b) => _ordenNombre == 'asc'
            ? nombre(a).compareTo(nombre(b))
            : nombre(b).compareTo(nombre(a)));
    }

    return list;
  }

  /// Distancia (m) del usuario al local; infinito si falta algún dato.
  double _distanciaA(Promotion p) {
    if (p.lat == null || p.lng == null || _userLat == null || _userLng == null) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(_userLat!, _userLng!, p.lat!, p.lng!);
  }

  /// Trae del backend los locales donde al cliente le queda canje disponible.
  Future<void> _cargarLocalesConCupon() async {
    final usuario = await authService.getUser();
    final clienteId = usuario?['_id'] as String?;
    if (clienteId == null) return;
    setState(() => _cargandoDisponibles = true);
    try {
      final ids = await CuponesService().localesDisponibles(clienteId);
      if (mounted) {
        setState(() {
          _localesConCupon
            ..clear()
            ..addAll(ids);
          _cargandoDisponibles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoDisponibles = false);
    }
  }

  /// Carga las ciudades de las provincias seleccionadas (para el filtro).
  Future<void> _cargarCiudadesFiltro() async {
    if (_selectedProvinciaIds.isEmpty) {
      _ciudadesFiltro = [];
      return;
    }
    try {
      final results = await Future.wait(
        _selectedProvinciaIds
            .map((id) => _ciudadesService.getParaPromosPorProvincia(id)),
      );
      final seen = <String>{};
      final merged = <Ciudad>[];
      for (final list in results) {
        for (final c in list) {
          if (seen.add(c.id)) merged.add(c);
        }
      }
      merged.sort((a, b) => a.nombre.compareTo(b.nombre));
      _ciudadesFiltro = merged;
    } catch (_) {
      _ciudadesFiltro = [];
    }
  }

  /// Bottom sheet de filtros avanzados.
  Future<void> _openFiltros() async {
    await _cargarCiudadesFiltro();
    if (!mounted) return;
    final ec = context.ec;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ec.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ec.strokeStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Filtros',
                        style: EnjoyTheme.heading(
                            size: 18, weight: FontWeight.w800, color: ec.text)),
                    const SizedBox(height: 8),
                    if (_ciudadesFiltro.isNotEmpty) ...[
                      const FieldLabel('Ciudad'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _cityChip('Todas', _selectedCiudadIds.isEmpty, () {
                            setState(() => _selectedCiudadIds.clear());
                            setSheet(() {});
                            _loadPromosByCities();
                          }),
                          for (final c in _ciudadesFiltro)
                            _cityChip(
                              c.nombre,
                              _selectedCiudadIds.contains(c.id),
                              () {
                                setState(() {
                                  if (_selectedCiudadIds.contains(c.id)) {
                                    _selectedCiudadIds.remove(c.id);
                                  } else {
                                    _selectedCiudadIds.add(c.id);
                                  }
                                });
                                setSheet(() {});
                                _loadPromosByCities();
                              },
                            ),
                        ],
                      ),
                      const EnjoyDivider(height: 26),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: ec.orange,
                      value: _ordenarCercania,
                      onChanged: _userLat == null
                          ? null
                          : (v) {
                              setState(() => _ordenarCercania = v);
                              setSheet(() {});
                              _loadPromosByCities();
                            },
                      title: Text('Ordenar por cercanía',
                          style: EnjoyTheme.body(
                              size: 15, weight: FontWeight.w600, color: ec.text)),
                      subtitle: Text(
                        _userLat == null
                            ? 'Activa la ubicación para usar este filtro'
                            : 'Muestra primero los locales más cercanos',
                        style: EnjoyTheme.body(size: 12, color: ec.textMute),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: ec.orange,
                      value: _soloConCupon,
                      onChanged: (v) async {
                        setState(() => _soloConCupon = v);
                        setSheet(() {});
                        if (v && _localesConCupon.isEmpty) {
                          await _cargarLocalesConCupon();
                          setSheet(() {});
                        }
                        _loadPromosByCities();
                      },
                      title: Text('Solo con cupón disponible',
                          style: EnjoyTheme.body(
                              size: 15, weight: FontWeight.w600, color: ec.text)),
                      subtitle: Text(
                          'Locales donde te queda canje sin usar',
                          style: EnjoyTheme.body(size: 12, color: ec.textMute)),
                    ),
                    if (_cargandoDisponibles)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: ec.orange)),
                          const SizedBox(width: 8),
                          Text('Buscando tus cupones…',
                              style: EnjoyTheme.body(
                                  size: 12, color: ec.textMute)),
                        ]),
                      ),
                    const EnjoyDivider(height: 22),
                    const FieldLabel('Ordenar por nombre'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final o in const [
                          ('none', 'Por defecto', Icons.clear_all_rounded),
                          ('asc', 'A → Z', Icons.arrow_upward_rounded),
                          ('desc', 'Z → A', Icons.arrow_downward_rounded),
                        ])
                          Pill(
                            o.$2,
                            icon: o.$3,
                            variant: _ordenNombre == o.$1
                                ? PillVariant.orange
                                : PillVariant.glass,
                            onTap: () {
                              setState(() => _ordenNombre = o.$1);
                              setSheet(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: EnjoyButton(
                          label: 'Limpiar',
                          variant: EnjoyButtonVariant.ghost,
                          onPressed: () {
                            setState(() {
                              _ordenarCercania = false;
                              _soloConCupon = false;
                              _selectedCiudadIds.clear();
                              _ordenNombre = 'none';
                            });
                            setSheet(() {});
                            _loadPromosByCities();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EnjoyButton(
                          label: 'Aplicar',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                    ]),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCityPickerAndReload() async {
    final result = await _pickProvincias();
    if (result != null) {
      await _aplicarProvincias(result);
    }
  }

  // ===== UI =====
  Widget _buildSelectCityPrompt() {
    final ec = context.ec;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          radius: 22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBox(Icons.location_on_outlined,
                  accent: true, size: 72, radius: 22, iconSize: 36),
              const SizedBox(height: 16),
              Text(
                'Elige tus provincias',
                style: EnjoyTheme.heading(
                    size: 20, weight: FontWeight.w700, color: ec.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Para ver las promociones disponibles, selecciona una o varias provincias y continúa.',
                textAlign: TextAlign.center,
                style: EnjoyTheme.body(size: 13, height: 1.35, color: ec.textMute),
              ),
              const SizedBox(height: 18),
              EnjoyButton(
                label: 'Seleccionar provincias',
                icon: Icons.map_outlined,
                expand: false,
                onPressed: _openCityPickerAndReload,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeBody() {
    final favs = context.watch<FavoritesStore>();
    final ec = context.ec;

    final showCta = !widget.guestMode && !_loadingCuponeras && _cuponeras.isEmpty;
    final promos = _applyFilters(_allPromos);

    return RefreshIndicator(
      color: ec.orange,
      backgroundColor: ec.surfaceMid,
      onRefresh: () => _loadPromosByCities(force: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical &&
              n.metrics.pixels >= n.metrics.maxScrollExtent - 300 &&
              _hasMore &&
              !_loadingMore) {
            _loadMoreFeed();
          }
          return false;
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // Tarjeta de membresía activa (hero) o CTA de adquisición.
            if (_cuponeras.isNotEmpty)
              _buildMembershipHero()
            else if (showCta)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildCuponeraCta(),
              ),
            const SizedBox(height: 8),

            // Bloque destacado UNIFICADO (Hoy + Flash en tabs) — más compacto.
            _buildDestacado(ec),

            // Categorías
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: SectionTitle('Categorías'),
            ),
            _buildCategorias(ec),
            const SizedBox(height: 12),

            // Para ti
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  Expanded(child: SectionTitle('Para ti')),
                  const SizedBox(width: 10),
                  GlassIconButton(
                    icon: Icons.tune_rounded,
                    accent: _filtrosActivos,
                    size: 40,
                    onTap: _openFiltros,
                  ),
                ],
              ),
            ),

            // Estados del feed
            if (_promosError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: ec.red),
                    const SizedBox(height: 8),
                    Text('No se pudieron cargar promociones.',
                        style: EnjoyTheme.body(size: 14, color: ec.red)),
                    const SizedBox(height: 8),
                    Text(_promosError!,
                        textAlign: TextAlign.center,
                        style: EnjoyTheme.body(size: 13, color: ec.textMute)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadPromosByCities,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (_selectedProvinciaIds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: _buildSelectCityPrompt(),
              )
            else if (_loadingPromos && promos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (promos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No hay promociones para tu selección.',
                      textAlign: TextAlign.center,
                      style: EnjoyTheme.body(size: 13, color: ec.textMute),
                    ),
                  ),
                ),
              )
            else
              ...promos.map((p) => _promoCard(p, favs)),

            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Bloque destacado UNIFICADO: "Hoy" + "Flash" en una sola sección con
  /// tabs internos. Cuando el usuario alterna, sólo cambia el contenido
  /// del carrusel — el bloque mantiene su altura total para no "saltar".
  Widget _buildDestacado(EnjoyColors ec) {
    final hayHoy = _loadingHoy || _promosHoy.isNotEmpty;
    final hayFlash = _allPromos.any((p) => p.tieneFlash);
    if (!hayHoy && !hayFlash) return const SizedBox.shrink();

    // Si una pestaña no aplica, fuerza la otra.
    final tabActivo = (!hayHoy && _destacadoTab == 'hoy')
        ? 'flash'
        : (!hayFlash && _destacadoTab == 'flash')
            ? 'hoy'
            : _destacadoTab;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con tabs internos.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              if (hayHoy)
                _miniTab(
                  ec,
                  icon: Icons.today_rounded,
                  label: 'Hoy',
                  active: tabActivo == 'hoy',
                  onTap: () => setState(() => _destacadoTab = 'hoy'),
                ),
              if (hayHoy && hayFlash) const SizedBox(width: 6),
              if (hayFlash)
                _miniTab(
                  ec,
                  icon: Icons.bolt_rounded,
                  label: 'Flash',
                  active: tabActivo == 'flash',
                  onTap: () => setState(() => _destacadoTab = 'flash'),
                ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => tabActivo == 'flash'
                        ? const PromocionesFlashScreen()
                        : const PromosHoyScreen(),
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tabActivo == 'flash'
                        ? ec.orange.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: tabActivo == 'flash'
                        ? Border.all(
                            color: ec.orange.withValues(alpha: 0.45))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tabActivo == 'flash') ...[
                        Icon(Icons.bolt_rounded,
                            size: 15, color: ec.orangeSoft),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        tabActivo == 'flash' ? 'Ver promos flash' : 'Ver todo',
                        style: EnjoyTheme.body(
                            size: 12.5,
                            color: ec.orangeSoft,
                            weight: FontWeight.w700),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: ec.orangeSoft),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Carrusel más compacto (alto 160 vs 210 anterior).
        SizedBox(
          height: 160,
          child: tabActivo == 'hoy'
              ? _carruselHoy(ec)
              : _carruselFlash(ec),
        ),
      ],
    );
  }

  Widget _miniTab(
    EnjoyColors ec, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? ec.orange.withValues(alpha: 0.18) : ec.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? ec.orange : ec.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? ec.orange : ec.textMute),
            const SizedBox(width: 4),
            Text(
              label,
              style: EnjoyTheme.body(
                size: 12.5,
                color: active ? ec.orange : ec.textSoft,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carruselHoy(EnjoyColors ec) {
    if (_loadingHoy && _promosHoy.isEmpty) {
      return Center(child: CircularProgressIndicator(color: ec.orange));
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _promosHoy.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final p = _promosHoy[i];
        return SizedBox(
          width: 140,
          child: _PromoHoyCard(
            promo: p,
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ComercioDetalleMiniScreen(usuarioId: p.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _carruselFlash(EnjoyColors ec) {
    final locales = _allPromos.where((p) => p.tieneFlash).take(15).toList();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: locales.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final p = locales[i];
        return SizedBox(
          width: 140,
          child: _PromoHoyCard(
            promo: p,
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ComercioDetalleMiniScreen(usuarioId: p.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Carrusel horizontal de categorías (chip "2x1" + categorías).
  Widget _buildCategorias(EnjoyColors ec) {
    return SizedBox(
      height: 44,
      child: _catsLoading
          ? const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : (_catsError != null)
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: ec.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('No se pudieron cargar categorías',
                            style: EnjoyTheme.body(size: 12, color: ec.red)),
                      ),
                      TextButton(
                        onPressed: _loadCategorias,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pill(
                        '2x1',
                        icon: Icons.local_offer_outlined,
                        variant: _selectedCats.contains('2x1')
                            ? PillVariant.orange
                            : PillVariant.glass,
                        onTap: () => _toggleCat('2x1'),
                      ),
                    ),
                    ..._categorias.map((c) {
                      final icon = _iconFor(c.icono);
                      final selected = _selectedCats.contains(c.nombre);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Pill(
                          c.nombre,
                          icon: icon,
                          variant: selected
                              ? PillVariant.orange
                              : PillVariant.glass,
                          onTap: () => _toggleCat(c.nombre),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }

  /// CTA en el home cuando el cliente NO tiene cuponeras: lo lleva a la
  /// Tarjeta de membresía activa (hero del Home) usando datos reales.
  Widget _buildMembershipHero() {
    final ec = context.ec;
    final c = _featuredCuponera;
    if (c == null) return const SizedBox.shrink();
    final vence = c.expiraEl != null
        ? 'Vigente hasta ${c.expiraEl!.day.toString().padLeft(2, '0')}/${c.expiraEl!.month.toString().padLeft(2, '0')}/${c.expiraEl!.year}'
        : 'Membresía activa';
    final localesCount =
        c.versionId != null ? _localesCountByVersion[c.versionId] : null;
    final localesLabel = localesCount != null
        ? '$localesCount ${localesCount == 1 ? "local" : "locales"} disponibles'
        : 'Ver locales disponibles';
    final hasMultiple = _cuponeras.length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: GlassCard(
        accent: true,
        radius: 24,
        padding: const EdgeInsets.all(18),
        onTap: () => _openCuponera(c),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: GlowHalo(size: 130, color: ec.glowOrange),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Pill('Activa', variant: PillVariant.green, dot: true),
                    if (hasMultiple)
                      GestureDetector(
                        onTap: _pickFeaturedCuponera,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded,
                                size: 15, color: ec.orangeSoft),
                            const SizedBox(width: 4),
                            Text('Cambiar',
                                style: EnjoyTheme.body(
                                    size: 12.5,
                                    weight: FontWeight.w700,
                                    color: ec.orangeSoft)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(c.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EnjoyTheme.heading(
                        size: 20, weight: FontWeight.w700, color: ec.text)),
                const SizedBox(height: 4),
                Text(vence, style: EnjoyTheme.body(size: 13, color: ec.textSoft)),
                const EnjoyDivider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_rounded,
                              size: 16, color: ec.orangeSoft),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(localesLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: EnjoyTheme.body(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: ec.text)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ver',
                            style: EnjoyTheme.heading(
                                size: 14,
                                weight: FontWeight.w700,
                                color: ec.orangeSoft)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            color: ec.orangeSoft, size: 16),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// pestaña de Cuponeras (donde está el flujo de adquisición).
  Widget _buildCuponeraCta() {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GlassCard(
        onTap: () => setState(() => _bottomIndex = 2),
        child: Row(
          children: [
            IconBox(Icons.local_activity_rounded, accent: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Aún no tienes una membresía',
                      style: EnjoyTheme.heading(
                          size: 14, weight: FontWeight.w800, color: ec.text)),
                  const SizedBox(height: 2),
                  Text('Adquiere una y empieza a ahorrar',
                      style: EnjoyTheme.body(size: 12, color: ec.textMute)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Pill('Adquirir', variant: PillVariant.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyByIndex() {
    if (_bottomIndex == 0) return _buildHomeBody();

    // ── Modo invitado: tab 1 = versiones para comprar ──
    if (widget.guestMode && _bottomIndex == 1) {
      return _GuestCuponerasView(onLogin: _goLogin);
    }

    if (_bottomIndex == 1) {
      final favsStore = context.watch<FavoritesStore>();
      final favs = _allPromos.where((p) => favsStore.isFav(p.id)).toList();
      return FavoritesScreenLight(
        promos: favs,
        onUnfavorite: (p) => favsStore.toggle(p.id),
      );
    }

    if (_bottomIndex == 2) {
      if (_loadingCuponeras) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_cuponerasError != null) {
        final ec = context.ec;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error al cargar membresías',
                style: EnjoyTheme.body(size: 14, color: ec.red),
              ),
              const SizedBox(height: 8),
              Text(_cuponerasError!,
                  textAlign: TextAlign.center,
                  style: EnjoyTheme.body(size: 13, color: ec.textMute)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadCuponeras,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );
      }
      return CuponerasScreenLight(cuponeras: _cuponeras);
    }

    return const SizedBox.shrink();
  }

  void _goLogin() {
    AuthService().exitGuestMode().then((_) {
      if (mounted) context.go('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;

    // Navbar: Inicio · Buscar · [QR] · Favoritos · Perfil (cliente).
    // Buscar, Perfil y el escáner se abren como pantalla propia (push); Inicio
    // y Favoritos cambian el cuerpo en sitio.
    final dockItems = widget.guestMode
        ? [
            DockItem(
                icon: Icons.home_rounded,
                label: 'Inicio',
                onTap: () => setState(() => _bottomIndex = 0)),
            DockItem(
                icon: Icons.local_activity_outlined,
                label: 'Membresías',
                onTap: () => setState(() => _bottomIndex = 1)),
          ]
        : [
            DockItem(
                icon: Icons.home_rounded,
                label: 'Inicio',
                onTap: () => setState(() => _bottomIndex = 0)),
            DockItem(
                icon: Icons.search_rounded,
                label: 'Buscar',
                onTap: _openBuscar),
            DockItem(
                icon: Icons.favorite_border_rounded,
                label: 'Favoritos',
                onTap: () => setState(() => _bottomIndex = 1)),
            DockItem(
                icon: Icons.person_outline_rounded,
                label: 'Perfil',
                onTap: _openPerfil),
          ];

    // Índice activo en el dock (Favoritos es el ítem 2 en la lista no-invitado).
    final dockIndex = widget.guestMode
        ? _bottomIndex
        : (_bottomIndex == 0
            ? 0
            : _bottomIndex == 1
                ? 2
                : -1);

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      extendBody: true,
      safeBottom: false,
      appBar: EnjoyAppBar(
        leading: _buildHeaderGreeting(ec),
        actions: [
          if (widget.guestMode)
            TextButton(
              onPressed: _goLogin,
              child: Text(
                'Iniciar sesión',
                style: EnjoyTheme.body(
                    size: 13, weight: FontWeight.w600, color: ec.orangeSoft),
              ),
            ),
          if (widget.guestMode) const SizedBox(width: 8),
          // 🔔 CAMPANA DE NOTIFICACIONES (solo logueados)
          if (!widget.guestMode)
            _NotifBellAction(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificacionesScreen(),
                  ),
                );
                // refrescar contador al volver
                setState(() {});
              },
            ),
          if (!widget.guestMode) const SizedBox(width: 4),
          // 📍 FILTRO DE PROVINCIA
          CityFilterIcon(
            count: _selectedProvinciaIds.length,
            onTap: () async {
              final result = await _pickProvincias();
              if (result != null) {
                await _aplicarProvincias(result);
              }
            },
          ),
        ],
      ),
      bottomBar: EnjoyDock(
        items: dockItems,
        currentIndex: dockIndex,
        fabIcon: Icons.card_membership_rounded,
        onFab: widget.guestMode ? null : () => setState(() => _bottomIndex = 2),
      ),
      body: SafeArea(bottom: false, child: _buildBodyByIndex()),
    );
  }

  // Saludo del header (avatar + "Hola, nombre"). Si el usuario tiene
  // fotoUrl/avatarUrl la mostramos en círculo; si no, mantenemos el IconBox.
  Widget _buildHeaderGreeting(EnjoyColors ec) {
    if (widget.guestMode) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBox(Icons.local_activity_rounded,
              accent: true, size: 40, radius: 13, iconSize: 20),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Bienvenido',
                  style: EnjoyTheme.body(size: 11, color: ec.textMute)),
              Text(
                'Invitado',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EnjoyTheme.heading(
                    size: 16, weight: FontWeight.w800, color: ec.text),
              ),
            ],
          ),
        ],
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService().getUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        String nombre = 'Invitado';
        String? fotoUrl;
        if (user != null) {
          if (user['nombres'] != null) {
            nombre =
                '${user['nombres']} ${user['apellidos'] ?? ''}'.trim();
          } else if (user['nombre'] != null) {
            nombre = user['nombre'];
          }
          final raw = (user['fotoUrl'] ?? user['avatarUrl'])?.toString();
          if (raw != null && raw.trim().isNotEmpty) fotoUrl = raw;
        }
        if (nombre.length > 18) {
          nombre = '${nombre.substring(0, 18).trimRight()}…';
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderAvatar(ec: ec, fotoUrl: fotoUrl, nombre: nombre),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hola,',
                    style: EnjoyTheme.body(size: 11, color: ec.textMute)),
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EnjoyTheme.heading(
                      size: 16, weight: FontWeight.w800, color: ec.text),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Widget de cuponeras disponibles para invitados
// ─────────────────────────────────────────────────────────────
class _GuestCuponerasView extends StatefulWidget {
  final VoidCallback onLogin;
  const _GuestCuponerasView({required this.onLogin});

  @override
  State<_GuestCuponerasView> createState() => _GuestCuponerasViewState();
}

class _GuestCuponerasViewState extends State<_GuestCuponerasView> {
  List<Map<String, dynamic>> _versiones = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await VersionesService.listarActivas();
      if (!mounted) return;
      setState(() {
        _versiones = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _verLocales(Map<String, dynamic> v) {
    final id = v['_id']?.toString() ?? '';
    if (id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleVersionScreen(versionId: id, versionData: v),
      ),
    );
  }

  Future<void> _verMapa(Map<String, dynamic> v) async {
    final id = v['_id']?.toString() ?? '';
    if (id.isEmpty) return;
    final nombre = v['nombre'] ?? 'Membresía';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final locales = await VersionesService.listarLocales(id);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapaVersionScreen(versionNombre: nombre, locales: locales),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el mapa.')),
      );
    }
  }

  void _showLoginDialog() {
    final ec = context.ec;
    showModalBottomSheet(
      context: context,
      backgroundColor: ec.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: ec.strokeStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // Ícono
            IconBox(Icons.local_activity_outlined,
                accent: true, size: 64, radius: 20, iconSize: 32),
            const SizedBox(height: 16),
            Text(
              '¡Crea tu cuenta para adquirir!',
              style: EnjoyTheme.heading(
                  size: 18, weight: FontWeight.w800, color: ec.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Para comprar una membresía necesitas una cuenta. Es rápido y gratis.',
              style: EnjoyTheme.body(size: 14, height: 1.4, color: ec.textMute),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            EnjoyButton(
              label: 'Iniciar sesión',
              onPressed: () {
                Navigator.pop(ctx);
                widget.onLogin();
              },
            ),
            const SizedBox(height: 10),
            EnjoyButton(
              label: 'Seguir explorando',
              variant: EnjoyButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _versiones;
    final q = _query.toLowerCase();
    return _versiones.where((v) {
      final nombre = (v['nombre'] ?? '').toString().toLowerCase();
      final desc = (v['descripcion'] ?? '').toString().toLowerCase();
      return nombre.contains(q) || desc.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error al cargar membresías',
                style: EnjoyTheme.body(size: 14, color: ec.red)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: EnjoyTheme.body(size: 14, color: ec.text),
            cursorColor: ec.orange,
            decoration: const InputDecoration(
              hintText: 'Buscar membresía…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    'No hay membresías disponibles',
                    style: EnjoyTheme.body(size: 13, color: ec.textMute),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final v = _filtered[i];
                    final nombre = v['nombre'] ?? 'Membresía';
                    final precio = v['precio'];
                    final descripcion = v['descripcion'] ?? '';
                    final imageUrl = v['imageUrl'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        radius: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18)),
                                child: EnjoyImage(
                                  imageUrl,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorWidget: const SizedBox.shrink(),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: EnjoyTheme.heading(
                                        size: 16,
                                        weight: FontWeight.w700,
                                        color: ec.text),
                                  ),
                                  if (descripcion.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      descripcion,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: EnjoyTheme.body(
                                          size: 13, color: ec.textMute),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (precio != null)
                                        Text(
                                          '\$${double.tryParse(precio.toString())?.toStringAsFixed(2) ?? precio}',
                                          style: EnjoyTheme.heading(
                                              size: 18,
                                              weight: FontWeight.w800,
                                              color: ec.orangeSoft),
                                        ),
                                      const Spacer(),
                                      EnjoyButton(
                                        label: 'Adquirir',
                                        expand: false,
                                        dense: true,
                                        onPressed: _showLoginDialog,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: EnjoyButton(
                                          label: 'Ver locales',
                                          icon: Icons.storefront_outlined,
                                          variant: EnjoyButtonVariant.ghost,
                                          dense: true,
                                          onPressed: () => _verLocales(v),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: EnjoyButton(
                                          label: 'Ver en mapa',
                                          icon: Icons.map_outlined,
                                          variant: EnjoyButtonVariant.ghost,
                                          dense: true,
                                          onPressed: () => _verMapa(v),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Card compacta para el carrusel "Promos de hoy".
class _PromoHoyCard extends StatelessWidget {
  final Promotion promo;
  final VoidCallback onTap;
  const _PromoHoyCard({required this.promo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final title = promo.placeName.isNotEmpty ? promo.placeName : promo.title;
    final cat = promo.categories.isNotEmpty ? promo.categories.first : promo.city;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ec.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ec.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 88,
                    width: double.infinity,
                    child: promo.coverUrl.isNotEmpty
                        ? EnjoyImage(promo.coverUrl, fit: BoxFit.cover)
                        : Container(color: ec.glassStrong),
                  ),
                  if (promo.tieneFlash)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: ec.accentGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.bolt_rounded,
                                size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'Flash',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (promo.isTwoForOne)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Pill('2x1', variant: PillVariant.orange),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EnjoyTheme.heading(size: 12.5, color: ec.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EnjoyTheme.body(size: 10.5, color: ec.textMute),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icono campana con badge de no-leídas. Polea el contador al construirse.
class _NotifBellAction extends StatefulWidget {
  final VoidCallback onTap;
  const _NotifBellAction({required this.onTap});

  @override
  State<_NotifBellAction> createState() => _NotifBellActionState();
}

class _NotifBellActionState extends State<_NotifBellAction> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _refrescar();
  }

  Future<void> _refrescar() async {
    try {
      final n = await CampanasService().noLeidas();
      if (mounted) setState(() => _count = n);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GestureDetector(
      onTap: () async {
        widget.onTap();
        // refresca al volver
        await Future.delayed(const Duration(milliseconds: 400));
        _refrescar();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassIconButton(
            icon: Icons.notifications_outlined,
            onTap: () async {
              widget.onTap();
              await Future.delayed(const Duration(milliseconds: 400));
              _refrescar();
            },
          ),
          if (_count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: ec.red,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ec.bgTop, width: 1.5),
                ),
                child: Text(
                  _count > 99 ? '99+' : '$_count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Avatar del header: foto del usuario si existe, IconBox como fallback.
class _HeaderAvatar extends StatelessWidget {
  final EnjoyColors ec;
  final String? fotoUrl;
  final String nombre;
  const _HeaderAvatar({
    required this.ec,
    required this.fotoUrl,
    required this.nombre,
  });

  @override
  Widget build(BuildContext context) {
    if (fotoUrl == null || fotoUrl!.trim().isEmpty) {
      return IconBox(
        Icons.local_activity_rounded,
        accent: true,
        size: 40,
        radius: 13,
        iconSize: 20,
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ec.orange.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ec.orange.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11.5),
        child: Image.network(
          fotoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackInitial(),
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              color: ec.glass,
              alignment: Alignment.center,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ec.orange,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fallbackInitial() {
    final letra = nombre.trim().isNotEmpty
        ? nombre.trim()[0].toUpperCase()
        : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ec.orange, ec.orangeSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letra,
        style: EnjoyTheme.heading(
          size: 18,
          weight: FontWeight.w900,
          color: ec.onAccent,
        ),
      ),
    );
  }
}
