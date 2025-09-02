import 'package:enjoy/screens/usuarios/profile_screen_light.dart';
import 'package:flutter/material.dart';
import '../../ui/palette.dart';
import '../../models/promotion_models.dart';
import '../../widgets/greeting_card.dart';
import '../../widgets/city_filter_icon.dart';
import '../../widgets/cities_sheet.dart';
import '../../widgets/segmented_tabs_light.dart';
import '../../widgets/category_chip_light.dart';
import '../../widgets/promos_list_light.dart';
import '../../widgets/floating_bottom_bar_light.dart';
import '../../widgets/promo_card_light.dart';
import 'favorites_screen_light.dart';
import 'search_screen_light.dart';
import 'cuponeras_screen_light.dart';

class PromotionsHomeScreen extends StatefulWidget {
  const PromotionsHomeScreen({super.key});

  @override
  State<PromotionsHomeScreen> createState() => _PromotionsHomeScreenState();
}

class _PromotionsHomeScreenState extends State<PromotionsHomeScreen>
    with SingleTickerProviderStateMixin {
  // ===== Estado principal =====
  late final TabController _tabController;
  String _query = '';
  final String _userName = 'Invitado';
  final List<String> _cities = const [
    'Ambato',
    'Latacunga',
    'Riobamba',
    'Quito',
    'Baños',
  ];
  final Set<String> _selectedCities = {'Ambato'};
  final Set<String> _selectedCats = {};
  final Set<String> _favoriteIds = {}; // favoritos

  final List<Promotion> allPromos = mockPromos;
  int _bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ====== Helpers ======
  void _toggleCat(String cat) {
    setState(
      () => _selectedCats.contains(cat)
          ? _selectedCats.remove(cat)
          : _selectedCats.add(cat),
    );
  }

  void _toggleFavorite(String promoId) {
    setState(
      () => _favoriteIds.contains(promoId)
          ? _favoriteIds.remove(promoId)
          : _favoriteIds.add(promoId),
    );
  }

  List<Promotion> _applyFilters(List<Promotion> input) {
    List<Promotion> list = input;
    if (_selectedCities.isNotEmpty) {
      list = list.where((p) => _selectedCities.contains(p.city)).toList();
    }
    if (_query.isNotEmpty) {
      list = list.where((p) {
        final haystack =
            '${p.title} ${p.placeName} ${p.description} ${p.category} ${(p.tags).join(" ")}'
                .toLowerCase();
        return haystack.contains(_query);
      }).toList();
    }
    if (_selectedCats.isNotEmpty) {
      list = list.where((p) {
        if (_selectedCats.contains('2x1') && !p.isTwoForOne) return false;
        if (_selectedCats.contains('Restaurantes') &&
            p.category != 'Restaurante')
          return false;
        if (_selectedCats.contains('Cafeterías') && p.category != 'Cafetería')
          return false;
        if (_selectedCats.contains('Bares') && p.category != 'Bar')
          return false;
        if (_selectedCats.contains('Spa') && p.category != 'Spa') return false;
        return true;
      }).toList();
    }
    return list;
  }

  Future<Set<String>?> _pickCities() async {
    final initial = {..._selectedCities};
    return showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Palette.kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            final temp = {...initial};
            return CitiesSheet(
              cities: _cities,
              selected: temp,
              onToggle: (c, v) {
                setModalState(() {
                  if (v)
                    temp.add(c);
                  else
                    temp.remove(c);
                  initial
                    ..clear()
                    ..addAll(temp);
                });
              },
              onClear: () => Navigator.pop(ctx, <String>{}),
              onApply: () => Navigator.pop(ctx, initial),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHomeBody() {
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
          height: 40,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              CategoryChipLight(
                label: '2x1',
                icon: Icons.local_offer_outlined,
                selected: _selectedCats.contains('2x1'),
                onTap: () => _toggleCat('2x1'),
              ),
              CategoryChipLight(
                label: 'Restaurantes',
                icon: Icons.restaurant_outlined,
                selected: _selectedCats.contains('Restaurantes'),
                onTap: () => _toggleCat('Restaurantes'),
              ),
              CategoryChipLight(
                label: 'Cafeterías',
                icon: Icons.coffee_outlined,
                selected: _selectedCats.contains('Cafeterías'),
                onTap: () => _toggleCat('Cafeterías'),
              ),
              CategoryChipLight(
                label: 'Bares',
                icon: Icons.wine_bar_outlined,
                selected: _selectedCats.contains('Bares'),
                onTap: () => _toggleCat('Bares'),
              ),
              CategoryChipLight(
                label: 'Spa',
                icon: Icons.spa_outlined,
                selected: _selectedCats.contains('Spa'),
                onTap: () => _toggleCat('Spa'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Listas por tabs
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              PromosListLight(
                promos: _applyFilters(allPromos),
                cardStyle: CardStyle.normal,
                isFavorite: (p) => _favoriteIds.contains(p.id),
                onFavorite: (p) => _toggleFavorite(p.id),
              ),
              PromosListLight(
                promos: _applyFilters(
                  allPromos.where((p) => p.isActiveToday).toList(),
                ),
                cardStyle: CardStyle.normal,
                isFavorite: (p) => _favoriteIds.contains(p.id),
                onFavorite: (p) => _toggleFavorite(p.id),
              ),
              PromosListLight(
                promos: _applyFilters(
                  allPromos.where((p) => p.isFlash).toList(),
                ),
                cardStyle: CardStyle.flash,
                isFavorite: (p) => _favoriteIds.contains(p.id),
                onFavorite: (p) => _toggleFavorite(p.id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBodyByIndex() {
    if (_bottomIndex == 0) return _buildHomeBody();
    if (_bottomIndex == 1) {
      final favs = allPromos.where((p) => _favoriteIds.contains(p.id)).toList();
      return FavoritesScreenLight(
        promos: favs,
        onUnfavorite: (p) => _toggleFavorite(p.id),
      );
    }
    if (_bottomIndex == 2) {
      return SearchScreenLight(
        all: allPromos,
        isFavorite: (p) => _favoriteIds.contains(p.id),
        onFavorite: (p) => _toggleFavorite(p.id),
      );
    }
    return CuponerasScreenLight(cuponeras: mockCuponeras);
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
              count: _selectedCities.isEmpty ? 0 : _selectedCities.length,
              onTap: () async {
                final result = await _pickCities();
                if (result != null) {
                  setState(() {
                    _selectedCities
                      ..clear()
                      ..addAll(result);
                  });
                }
              },
            ),
          ),
        ],
        // 👇 GreetingCard siempre; tabs solo en Home
        bottom: PreferredSize(
          // altura dinámica: con tabs vs sin tabs
          preferredSize: Size.fromHeight(_bottomIndex == 0 ? 140 : 82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: GreetingCard(
                  name: _userName,
                  onViewProfile: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreenLight(
                          name: 'Invitado',
                          email: 'invitado@tuapp.com',
                          avatarUrl: '', // si tienes una url, colócala aquí
                          favoritos: 12,
                          cuponeras: 2,
                          escaneos: 7,
                          ciudades: ['Ambato', 'Riobamba'],
                          categoriasFav: ['Restaurantes', 'Cafeterías', 'Spa'],
                        ),
                      ),
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
                const SizedBox(
                  height: 0,
                ), // un respiro pequeño cuando no hay tabs
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
