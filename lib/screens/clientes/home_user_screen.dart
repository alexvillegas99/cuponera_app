import 'dart:convert';

import 'package:enjoy/mappers/cuponera.dart';
import 'package:enjoy/models/categoria.dart';
import 'package:enjoy/models/ciudad.dart';
import 'package:enjoy/screens/clientes/cuponeras_screen_light.dart';
import 'package:enjoy/screens/clientes/favorites_screen_light.dart';
import 'package:enjoy/screens/clientes/profile_screen_light.dart';
import 'package:enjoy/screens/clientes/search_screen_light.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/categorias_service.dart';
import 'package:enjoy/services/ciudades_service.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/services/promotions_service.dart';
import 'package:enjoy/state/favorites_store.dart';
import 'package:enjoy/widgets/promo_card_light.dart' show CardStyle;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/palette.dart';
import '../../models/promotion_models.dart';
import '../../widgets/greeting_card.dart';
import '../../widgets/city_filter_icon.dart';
import '../../widgets/cities_sheet.dart';
import '../../widgets/segmented_tabs_light.dart';
import '../../widgets/category_chip_light.dart';
import '../../widgets/promos_list_light.dart';
import '../../widgets/floating_bottom_bar_light.dart';

const _kSelectedCityIdsKey = 'selected_city_ids_v1';
const _kNotifPromos = 'notif_promos_v1';
const _kCityTopicsPrefs = 'notif_city_topics_v2';

class PromotionsHomeScreen extends StatefulWidget {
  const PromotionsHomeScreen({super.key});

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
  final FirebaseMessaging _fm = FirebaseMessaging.instance;

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
  bool _isValidTopic(String t) => t.isNotEmpty && t.length <= 900 && _topicRegex.hasMatch(t);

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
    final prefs = await SharedPreferences.getInstance();
    final promosOn = prefs.getBool(_kNotifPromos) ?? true;

    // 1) carga actual
    final current = await _loadTopicsSet();
    final currentValid = current.where(_isValidTopic).toSet();
    debugPrint('🔵 [_syncCityTopics] actual: $currentValid');

    // 2) si OFF o sin ciudades -> desuscribir todo
    if (!promosOn || _selectedCityIds.isEmpty) {
      debugPrint('⚠️ promosOn=$promosOn, ciudades=${_selectedCityIds.length} → unsubscribe all');
      for (final t in currentValid) {
        await _fm.unsubscribeFromTopic(t);
      }
      await _saveTopicsSet(<String>{});
      return;
    }

    // 3) deseados
    final desiredRaw = _selectedCityIds.map(_cityTopicForId).toSet();
    final desired = desiredRaw.where(_isValidTopic).toSet();

    // 4) diff
    final toSub = desired.difference(currentValid);
    final toUnsub = currentValid.difference(desired);

    // 5) permisos
    final s = await _fm.getNotificationSettings();
    if (s.authorizationStatus != AuthorizationStatus.authorized &&
        s.authorizationStatus != AuthorizationStatus.provisional) {
      final r = await _fm.requestPermission(alert: true, badge: true, sound: true);
      final ok = r.authorizationStatus == AuthorizationStatus.authorized ||
          r.authorizationStatus == AuthorizationStatus.provisional;
      if (!ok) {
        debugPrint('❌ Permisos notifs denegados, guardar desired y salir');
        await _saveTopicsSet(desired);
        return;
      }
    }

    // 6) aplicar
    for (final t in toSub) {
      await _fm.subscribeToTopic(t);
    }
    for (final t in toUnsub) {
      await _fm.unsubscribeFromTopic(t);
    }

    // 7) persistir
    await _saveTopicsSet(desired);
  }

  // ===== Persistencia de selección de ciudades =====
  Future<void> _saveSelectedCityIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _selectedCityIds.toList();
    _log('SAVE -> ${list.length} ids: $list');
    final ok = await prefs.setStringList(_kSelectedCityIdsKey, list);
    _log('SAVE result: $ok');
  }

  Future<void> _restoreSavedCitySelection() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kSelectedCityIdsKey) ?? const [];
    _log('RESTORE raw -> ${saved.length} ids: $saved');

    if (saved.isEmpty) return;

    final validIds = _ciudades.map((c) => c.id).toSet();
    final toApply = saved.where(validIds.contains).toSet();

    _log('RESTORE valid -> ${toApply.length} ids');

    if (toApply.isEmpty) return;

    setState(() {
      _selectedCityIds
        ..clear()
        ..addAll(toApply);
    });

    _log('STATE after RESTORE -> $_selectedCityIds');
  }

  // ===== Orquestación =====
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initScreen();
  }

  Future<void> _initScreen() async {
    try {
      await _loadCategorias();
      await _loadCiudades();
      await _restoreSavedCitySelection();
      await _syncCityTopics();
      await _loadPromosByCities();
      await _loadCuponeras();
      await _initFavoritesOnce();
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
  Future<void> _loadCiudades() async {
    try {
      final cities = await _ciudadesService.getParaPromos();
      _ciudades = cities;

      _cityIdByName
        ..clear()
        ..addEntries(cities.map((c) => MapEntry(c.nombre, c.id)));
      _cityNameById
        ..clear()
        ..addEntries(cities.map((c) => MapEntry(c.id, c.nombre)));

      _citiesLoading = false;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _citiesError = e.toString();
          _citiesLoading = false;
        });
      }
    }
  }

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
  // ✅ Si no hay ciudades seleccionadas, NO llames al backend
  if (_selectedCityIds.isEmpty) {
    if (mounted) {
      setState(() {
        _allPromos = [];
        _promosError = null;   // no mostrar error
        _loadingPromos = false;
      });
    }
    return;
  }

  try {
    setState(() => _loadingPromos = true);
    final promos = await _promoService.getAllActivePromos(
      cityIds: _selectedCityIds.toList(),
    );
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
      debugPrint('[PROMO] title="${p.title}" id=${p.id} detailId=${p.detailId}');
    }
  }

  // ===== Aplicadores =====
  Future<void> _applyCitySelection(Set<String> ids) async {
    setState(() {
      _selectedCityIds
        ..clear()
        ..addAll(ids);
    });
    await _saveSelectedCityIds();
    await _syncCityTopics();
    await _loadPromosByCities();
  }

  void _toggleCat(String cat) {
    setState(() => _selectedCats.contains(cat)
        ? _selectedCats.remove(cat)
        : _selectedCats.add(cat));
  }

  Future<Set<String>?> _pickCities() async {
    final initialNames = {..._selectedCityNames};

    final chosenNames = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Palette.kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            final temp = {...initialNames};
            return CitiesSheet(
              cities: _cityNames,
              selected: temp,
              onToggle: (c, v) {
                setModalState(() {
                  if (v) temp.add(c); else temp.remove(c);
                  initialNames
                    ..clear()
                    ..addAll(temp);
                });
              },
              onClear: () => Navigator.pop(ctx, <String>{}),
              onApply: () => Navigator.pop(ctx, initialNames),
            );
          },
        ),
      ),
    );

    if (chosenNames == null) return null;

    final ids = <String>{};
    for (final name in chosenNames) {
      final id = _cityIdByName[name];
      if (id != null) ids.add(id);
    }
    return ids;
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

  IconData _iconFor(String? icon) {
    const Map<String, IconData> iconMap = {
      'parrillada': Icons.outdoor_grill_outlined,
      'bbq': Icons.outdoor_grill_outlined,
      'grill': Icons.outdoor_grill_outlined,
      'asado': Icons.outdoor_grill_outlined,
      'restaurant': Icons.restaurant_outlined,
      'utensils': Icons.restaurant_outlined,
      'food': Icons.fastfood_outlined,
      'fastfood': Icons.fastfood_outlined,
      'pizza': Icons.local_pizza_outlined,
      'burger': Icons.lunch_dining_outlined,
      'dining': Icons.dining_outlined,
      'coffee': Icons.coffee_outlined,
      'cafe': Icons.coffee_outlined,
      'tea': Icons.emoji_food_beverage_outlined,
      'bar': Icons.wine_bar_outlined,
      'beer': Icons.local_drink_outlined,
      'cocktail': Icons.local_bar_outlined,
      'shop': Icons.storefront_outlined,
      'store': Icons.store_outlined,
      'mall': Icons.shopping_bag_outlined,
      'market': Icons.local_grocery_store_outlined,
      'spa': Icons.spa_outlined,
      'gym': Icons.fitness_center_outlined,
      'wellness': Icons.self_improvement_outlined,
      'pharmacy': Icons.local_pharmacy_outlined,
      'cinema': Icons.movie_outlined,
      'theater': Icons.theaters_outlined,
      'music': Icons.music_note_outlined,
      'karaoke': Icons.mic_outlined,
      'game': Icons.sports_esports_outlined,
      'bowling': Icons.sports_baseball_outlined,
      'hotel': Icons.hotel_outlined,
      'bed': Icons.bed_outlined,
      'travel': Icons.flight_outlined,
      'beach': Icons.beach_access_outlined,
      'museum': Icons.account_balance_outlined,
      'park': Icons.park_outlined,
      'beauty': Icons.brush_outlined,
      'hair': Icons.cut_outlined,
      'nails': Icons.brush_outlined,
      'car': Icons.directions_car_outlined,
      'bike': Icons.pedal_bike_outlined,
      'taxi': Icons.local_taxi_outlined,
      'bus': Icons.directions_bus_outlined,
      'tech': Icons.devices_outlined,
      'computer': Icons.computer_outlined,
      'phone': Icons.phone_android_outlined,
      'office': Icons.apartment_outlined,
      'education': Icons.school_outlined,
      'book': Icons.menu_book_outlined,
      'time': Icons.access_time_outlined,
      'clock': Icons.schedule_outlined,
    };

    if (icon == null) return Icons.category_outlined;
    final normalized = icon.toLowerCase().trim();
    return iconMap[normalized] ?? Icons.category_outlined;
  }

  List<Promotion> _applyFilters(List<Promotion> input) {
    List<Promotion> list = input;

    // 🔹 Filtrado por ciudades SOLO por nombre (no existe cityId en Promotion)
    if (_selectedCityIds.isNotEmpty) {
      final selectedNames = _selectedCityIds
          .map((id) => _cityNameById[id])
          .whereType<String>()
          .toSet();

      list = list.where((p) => selectedNames.contains(p.city)).toList();
    }

    // 🔹 Búsqueda de texto
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((p) {
        final haystack = '${p.title} ${p.placeName} ${p.description} '
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
    if (_citiesLoading) return;
    if (_citiesError != null) {
      await _loadCiudades();
    }
    final ids = await _pickCities();
    if (ids != null) {
      await _applyCitySelection(ids);
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Palette.kBorder),
            boxShadow: const [
              BoxShadow(
                blurRadius: 20,
                offset: Offset(0, 10),
                color: Color(0x11000000),
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
                'Elige tu ciudad',
                style: TextStyle(
                  color: Palette.kTitle,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Para ver las promociones disponibles, selecciona al menos una ciudad y continúa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.kMuted, height: 1.35),
              ),
              const SizedBox(height: 16),

              if (_ciudades.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ciudades.take(4).map((c) {
                    final selected = _selectedCityIds.contains(c.id);
                    return GestureDetector(
                      onTap: () async {
                        final newSet = {..._selectedCityIds};
                        if (selected) newSet.remove(c.id); else newSet.add(c.id);
                        await _applyCitySelection(newSet);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Palette.kAccent.withOpacity(0.12)
                              : Palette.kField,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? Palette.kAccent : Palette.kBorder,
                            width: selected ? 1.2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selected ? Icons.check_circle : Icons.circle_outlined,
                              size: 16,
                              color: selected ? Palette.kAccent : Palette.kMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              c.nombre,
                              style: TextStyle(
                                color: selected ? Palette.kAccent : Palette.kTitle,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openCityPickerAndReload,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Seleccionar ciudad'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Palette.kTitle,
                      side: const BorderSide(color: Palette.kBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_citiesError != null)
                    FilledButton.icon(
                      onPressed: _loadCiudades,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.kAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            onChanged: (q) => setState(() => _query = q.trim().toLowerCase()),
            style: const TextStyle(color: Palette.kTitle),
            cursorColor: Palette.kAccent,
            decoration: InputDecoration(
              hintText: 'Buscar por local, plato o categoría…',
              hintStyle: const TextStyle(color: Palette.kMuted),
              prefixIcon: const Icon(Icons.search, color: Palette.kMuted, size: 22),
              filled: true,
              fillColor: Palette.kField,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Palette.kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Palette.kAccent, width: 1.2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Categorías
        SizedBox(
          height: 40,
          child: _catsLoading
              ? const Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (_catsError != null)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'No se pudieron cargar categorías',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                          TextButton(onPressed: _loadCategorias, child: const Text('Reintentar')),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      TextButton(onPressed: _loadPromosByCities, child: const Text('Reintentar')),
                    ],
                  ),
                );
              }

              if (_selectedCityIds.isEmpty) {
                return _buildSelectCityPrompt();
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  PromosListLight(
                    promos: _applyFilters(_allPromos),
                    cardStyle: CardStyle.normal,
                    isFavorite: (p) => favs.isFav(p.id),
                    onFavorite: (p) => context.read<FavoritesStore>().toggle(p.id),
                  ),
                  PromosListLight(
                    promos: _applyFilters(_onlyToday(_allPromos)),
                    cardStyle: CardStyle.normal,
                    isFavorite: (p) => favs.isFav(p.id),
                    onFavorite: (p) => context.read<FavoritesStore>().toggle(p.id),
                  ),
                  PromosListLight(
                    promos: _applyFilters(_allPromos.where((p) => p.isFlash).toList()),
                    cardStyle: CardStyle.flash,
                    isFavorite: (p) => favs.isFav(p.id),
                    onFavorite: (p) => context.read<FavoritesStore>().toggle(p.id),
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

    if (_bottomIndex == 1) {
      final favsStore = context.watch<FavoritesStore>();
      final favs = _allPromos.where((p) => favsStore.isFav(p.id)).toList();
      return FavoritesScreenLight(
        promos: favs,
        onUnfavorite: (p) => favsStore.toggle(p.id),
      );
    }

    if (_bottomIndex == 2) {
      return SearchScreenLight(
        all: _allPromos,
        isFavorite: (p) => context.watch<FavoritesStore>().isFav(p.id),
        onFavorite: (p) => context.read<FavoritesStore>().toggle(p.id),
      );
    }

    if (_bottomIndex == 3) {
      if (_loadingCuponeras) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_cuponerasError != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Error al cargar cuponeras', style: TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
              Text(_cuponerasError!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadCuponeras, child: const Text('Reintentar')),
            ],
          ),
        );
      }
      return CuponerasScreenLight(cuponeras: _cuponeras);
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CityFilterIcon(
              count: _selectedCityIds.isEmpty ? 0 : _selectedCityIds.length,
              onTap: () async {
                if (_citiesLoading) return;
                if (_citiesError != null) {
                  await _loadCiudades();
                  return;
                }
                final resultIds = await _pickCities();
                if (resultIds != null) {
                  await _applyCitySelection(resultIds);
                }
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_bottomIndex == 0 ? 140 : 82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: GreetingCard(
                  onViewProfile: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreenLight()),
                    );
                  },
                ),
              ),
              if (_bottomIndex == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: SegmentedTabsLight(controller: _tabController),
                )
              else
                const SizedBox(height: 0),
            ],
          ),
        ),
      ),
      body: _buildBodyByIndex(),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: FloatingBottomBarLight(
          index: _bottomIndex,
          onTap: (i) => setState(() => _bottomIndex = i),
        ),
      ),
    );
  }
}
