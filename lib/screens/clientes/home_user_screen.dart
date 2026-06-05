import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:enjoy/mappers/cuponera.dart';
import 'package:enjoy/models/categoria.dart';
import 'package:enjoy/models/ciudad.dart';
import 'package:enjoy/models/provincia.dart';
import 'package:enjoy/screens/clientes/cuponeras_screen_light.dart';
import 'package:enjoy/screens/clientes/favorites_screen_light.dart';
import 'package:enjoy/screens/clientes/profile_screen_light.dart';
import 'package:enjoy/screens/clientes/search_screen_light.dart';
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
import 'package:enjoy/widgets/promo_card_light.dart' show CardStyle;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/palette.dart';
import '../../models/promotion_models.dart';
import '../../widgets/greeting_card.dart';
import '../../widgets/city_filter_icon.dart';
import '../../widgets/province_cities_picker.dart';
import '../../widgets/segmented_tabs_light.dart';
import '../../widgets/category_chip_light.dart';
import '../../widgets/promos_list_light.dart';
import '../../widgets/floating_bottom_bar_light.dart';

const _kSelectedCityIdsKey = 'selected_city_ids_v1';
const _kSelectedProvinciasKey = 'selected_provincia_ids_v1';
const _kNotifPromos = 'notif_promos_v1';
const _kCityTopicsPrefs = 'notif_city_topics_v2';

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

  String _query = '';
  final Set<String> _selectedCats = {};

  // ===== Cuponeras =====
  List<Cuponera> _cuponeras = [];
  bool _loadingCuponeras = true;
  String? _cuponerasError;

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
    _tabController = TabController(length: 3, vsync: this);
    _initScreen();
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

  Future<void> _loadPromosByCities() async {
    // ✅ Multi-provincia: si no hay provincias elegidas, NO llames al backend
    if (_selectedProvinciaIds.isEmpty) {
      if (mounted) {
        setState(() {
          _allPromos = [];
          _promosError = null;
          _loadingPromos = false;
        });
      }
      return;
    }

    try {
      setState(() => _loadingPromos = true);
      // Trae TODOS los locales de las provincias elegidas (backend expande a ciudades).
      final promos =
          await _promoService.getByProvincias(_selectedProvinciaIds.toList());
      if (mounted) {
        setState(() {
          _allPromos = promos;
          _promosError = null;
          _loadingPromos = false;
        });
      }
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

      final list = await CuponesService().listarPorCliente(
        clienteId,
        soloActivas: true,
      );
      setState(() {
        _cuponeras = list;
        _loadingCuponeras = false;
      });
    } catch (e) {
      setState(() {
        _cuponerasError = e.toString();
        _loadingCuponeras = false;
      });
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

    return list;
  }

  Future<void> _openCityPickerAndReload() async {
    final result = await _pickProvincias();
    if (result != null) {
      await _aplicarProvincias(result);
    }
  }

  // ===== UI =====
  Widget _buildSelectCityPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Palette.kSurface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                offset: const Offset(0, 4),
                color: Colors.black.withOpacity(0.05),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  color: Palette.kAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 36,
                  color: Palette.kAccent,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Elige tus provincias',
                style: TextStyle(
                  color: Palette.kTitle,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Para ver las promociones disponibles, selecciona una o varias provincias y continúa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.kMuted, height: 1.35),
              ),
              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _openCityPickerAndReload,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Seleccionar provincias'),
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.kAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeBody() {
    final favs = context.watch<FavoritesStore>();

    return Column(
      children: [
        // Buscar
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (q) => setState(() => _query = q.trim().toLowerCase()),
            style: const TextStyle(color: Palette.kTitle),
            cursorColor: Palette.kAccent,
            decoration: InputDecoration(
              hintText: 'Buscar por local, plato o categoría…',
              hintStyle: const TextStyle(color: Palette.kMuted),
              prefixIcon: const Icon(
                Icons.search,
                color: Palette.kMuted,
                size: 22,
              ),
              filled: true,
              fillColor: Palette.kField,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Palette.kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Palette.kAccent,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Categorías
        SizedBox(
          height: 48,
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
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No se pudieron cargar categorías',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
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
                    CategoryChipLight(
                      label: '2x1',
                      icon: Icons.local_offer_outlined,
                      selected: _selectedCats.contains('2x1'),
                      onTap: () => _toggleCat('2x1'),
                    ),
                    ..._categorias.map((c) {
                      final icon = _iconFor(c.icono);
                      final selected = _selectedCats.contains(c.nombre);
                      return CategoryChipLight(
                        label: c.nombre,
                        icon: icon,
                        selected: selected,
                        onTap: () => _toggleCat(c.nombre),
                      );
                    }),
                  ],
                ),
        ),
        const SizedBox(height: 8),

        // Cuerpo por estados claros
        Expanded(
          child: Builder(
            builder: (_) {
              if (_loadingPromos) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_promosError != null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(height: 8),
                      const Text(
                        'No se pudieron cargar promociones.',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 8),
                      Text(_promosError!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadPromosByCities,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }

              if (_selectedProvinciaIds.isEmpty) {
                return _buildSelectCityPrompt();
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  PromosListLight(
                    promos: _applyFilters(_allPromos),
                    cardStyle: CardStyle.compact,
                    userLat: _userLat,
                    userLng: _userLng,
                    isFavorite: (p) => favs.isFav(p.id),
                    onFavorite: (p) =>
                        context.read<FavoritesStore>().toggle(p.id),
                  ),
                  PromosListLight(
                    promos: _applyFilters(_onlyToday(_allPromos)),
                    cardStyle: CardStyle.compact,
                    userLat: _userLat,
                    userLng: _userLng,
                    isFavorite: (p) => favs.isFav(p.id),
                    onFavorite: (p) =>
                        context.read<FavoritesStore>().toggle(p.id),
                  ),
                  PromosListLight(
                    promos: _applyFilters(
                      _allPromos.where((p) => p.isFlash).toList(),
                    ),
                    cardStyle: CardStyle.flash,
                    userLat: _userLat,
                    userLng: _userLng,
                    isFavorite: (p) => favs.isFav(p.id),
                    onFavorite: (p) =>
                        context.read<FavoritesStore>().toggle(p.id),
                  ),
                ],
              );
            },
          ),
        ),
      ],
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
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Error al cargar cuponeras',
                style: TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
              Text(_cuponerasError!, textAlign: TextAlign.center),
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
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        titleSpacing: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Palette.kSurface,
            border: Border(
              bottom: BorderSide(color: Palette.kBorder, width: 1),
            ),
          ),
        ),

        // 👇 Logo + Hola + nombre
        title: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Palette.kAccent, Palette.kAccentLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.kAccent.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.local_activity_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              widget.guestMode
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Bienvenido', style: TextStyle(fontSize: 11, color: Palette.kMuted)),
                        Text(
                          'Invitado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Palette.kTitle),
                        ),
                      ],
                    )
                  : FutureBuilder<Map<String, dynamic>?>(
                      future: AuthService().getUser(),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        String nombre = 'Invitado';
                        if (user != null) {
                          if (user['nombres'] != null) {
                            nombre = '${user['nombres']} ${user['apellidos'] ?? ''}'.trim();
                          } else if (user['nombre'] != null) {
                            nombre = user['nombre'];
                          }
                        }
                        // Evita que un nombre muy largo se sobreponga en el header.
                        if (nombre.length > 18) {
                          nombre = '${nombre.substring(0, 18).trimRight()}…';
                        }
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Hola,', style: TextStyle(fontSize: 11, color: Palette.kMuted)),
                            Text(
                              nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Palette.kTitle,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ],
          ),
        ),

        actions: [
          // 👤 PERFIL o INICIAR SESIÓN (invitado)
          widget.guestMode
              ? Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton(
                    onPressed: _goLogin,
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(color: Palette.kAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              : _HomeAppBarBtn(
                  icon: Icons.account_circle_outlined,
                  color: Palette.kPrimary,
                  tooltip: 'Perfil',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreenLight()),
                    );
                  },
                ),
          const SizedBox(width: 8),

          // 📍 FILTRO DE PROVINCIA
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CityFilterIcon(
              count: _selectedProvinciaIds.length,
              onTap: () async {
                final result = await _pickProvincias();
                if (result != null) {
                  await _aplicarProvincias(result);
                }
              },
            ),
          ),
        ],

        bottom: _bottomIndex == 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SegmentedTabsLight(controller: _tabController),
                ),
              )
            : null,
      ),

      body: _buildBodyByIndex(),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: FloatingBottomBarLight(
          index: _bottomIndex,
          onTap: (i) => setState(() => _bottomIndex = i),
          items: widget.guestMode
              ? const [
                  NavItem(icon: Icons.home_filled, label: 'Inicio'),
                  NavItem(icon: Icons.local_activity_outlined, label: 'Cuponeras'),
                ]
              : const [
                  NavItem(icon: Icons.home_filled, label: 'Inicio'),
                  NavItem(icon: Icons.favorite, label: 'Favoritos'),
                  NavItem(icon: Icons.qr_code_2, label: 'Cuponeras'),
                ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Botón de AppBar estilizado
// ─────────────────────────────────────────────────────────────
class _HomeAppBarBtn extends StatelessWidget {
  const _HomeAppBarBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
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
    final nombre = v['nombre'] ?? 'Cuponera';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Palette.kAccent)),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // Ícono
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Palette.kAccent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_activity_outlined, color: Palette.kAccent, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Crea tu cuenta para adquirir!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Palette.kTitle,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Para comprar una cuponera necesitas una cuenta. Es rápido y gratis.',
              style: TextStyle(color: Palette.kMuted, fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onLogin();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.kAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Iniciar sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.kMuted,
                  side: BorderSide(color: Palette.kBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Seguir explorando'),
              ),
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: Palette.kAccent));

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Error al cargar cuponeras', style: TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Buscar cuponera…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Palette.kField,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Palette.kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Palette.kAccent),
              ),
            ),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    'No hay cuponeras disponibles',
                    style: TextStyle(color: Palette.kMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final v = _filtered[i];
                    final nombre = v['nombre'] ?? 'Cuponera';
                    final precio = v['precio'];
                    final descripcion = v['descripcion'] ?? '';
                    final imageUrl = v['imageUrl'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Palette.kSurface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              child: Image.network(
                                imageUrl,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.kTitle,
                                  ),
                                ),
                                if (descripcion.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    descripcion,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Palette.kMuted, fontSize: 13),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (precio != null)
                                      Text(
                                        '\$${double.tryParse(precio.toString())?.toStringAsFixed(2) ?? precio}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Palette.kAccent,
                                        ),
                                      ),
                                    const Spacer(),
                                    ElevatedButton(
                                      onPressed: _showLoginDialog,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Palette.kAccent,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      ),
                                      child: const Text('Adquirir'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _verLocales(v),
                                        icon: const Icon(Icons.storefront_outlined, size: 16),
                                        label: const Text('Ver locales'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Palette.kPrimary,
                                          side: BorderSide(color: Palette.kPrimary.withOpacity(0.35)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _verMapa(v),
                                        icon: const Icon(Icons.map_outlined, size: 16),
                                        label: const Text('Ver en mapa'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Palette.kPrimary,
                                          side: BorderSide(color: Palette.kPrimary.withOpacity(0.35)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
