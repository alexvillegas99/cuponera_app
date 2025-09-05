import 'package:enjoy/models/categoria.dart';
import 'package:enjoy/screens/clientes/profile_screen_light.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/categorias_service.dart';
import 'package:enjoy/services/promotions_service.dart';
import 'package:enjoy/state/favorites_store.dart';
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
import 'package:provider/provider.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/mappers/cuponera.dart';


class PromotionsHomeScreen extends StatefulWidget {
  const PromotionsHomeScreen({super.key});

  @override
  State<PromotionsHomeScreen> createState() => _PromotionsHomeScreenState();
}

class _PromotionsHomeScreenState extends State<PromotionsHomeScreen>




    with SingleTickerProviderStateMixin {
  List<Promotion> _onlyToday(List<Promotion> input) {
    final today = DateTime.now();
    final filtered = <Promotion>[];

    debugPrint('--- FILTRO HOY (solo aplicaTodosLosDias/diasAplicables) ---');
    for (final p in input) {
      final res = p.appliesTodaySimple(today);
      debugPrint(
        '[Hoy?] ${p.title} '
        '| aplicaTodosLosDias=${p.aplicaTodosLosDias} '
        '| dias=${p.diasAplicables} '
        '=> $res',
      );
      if (res) filtered.add(p);
    }
    debugPrint('--- TOTAL HOY: ${filtered.length} ---');

    return filtered;
  }
  final authService = AuthService();


  // ===== Estado principal =====
  late final TabController _tabController;

  final _catService = CategoriasService();
  final _promoService = PromotionsService();
  List<Categoria> _categorias = [];
  bool _catsLoading = true;
  String? _catsError;

  Future<void> _loadCategorias() async {
    try {
      final cats = await _catService.getActivas();
      setState(() {
        _categorias = cats;
        _catsLoading = false;
      });
    } catch (e) {
      setState(() {
        _catsError = e.toString();
        _catsLoading = false;
      });
    }
  }


  // ...

final _cuponesService = CuponesService();
List<Cuponera> _cuponeras = [];
bool _loadingCuponeras = true;
String? _cuponerasError;


// Llamar esto en initState (después de cargar usuario), o en didChangeDependencies
Future<void> _loadCuponeras() async {
  try {
    final usuario = await authService.getUser();           // ya lo usas
    final clienteId = usuario?['_id'] as String?;          // Asegúrate de que esto devuelve el MongoID
    if (clienteId == null) {
      setState(() {
        _cuponerasError = 'No hay clienteId';
        _loadingCuponeras = false;
      });
      return;
    }
    
    final list = await _cuponesService.listarPorCliente(clienteId, soloActivas: true);
    print('lista de cuponeras $list');
    setState(() {
      _cuponeras = list;
         print('lista $list');
      _loadingCuponeras = false;
    });
  } catch (e) {
    setState(() {
      _cuponerasError = e.toString();
         print('lista $_cuponerasError');
      _loadingCuponeras = false;
    });
  }
}

  IconData _iconFor(String? icon) {
    // Diccionario de iconos conocidos
    const Map<String, IconData> iconMap = {
      // Parrilladas / BBQ
      'parrillada': Icons.outdoor_grill_outlined,
      'bbq': Icons.outdoor_grill_outlined,
      'grill': Icons.outdoor_grill_outlined,
      'asado': Icons.outdoor_grill_outlined,
      // Restaurantes / comida
      'restaurant': Icons.restaurant_outlined,
      'utensils': Icons.restaurant_outlined,
      'food': Icons.fastfood_outlined,
      'fastfood': Icons.fastfood_outlined,
      'pizza': Icons.local_pizza_outlined,
      'burger': Icons.lunch_dining_outlined,
      'dining': Icons.dining_outlined,

      // Café / bebidas
      'coffee': Icons.coffee_outlined,
      'cafe': Icons.coffee_outlined,
      'tea': Icons.emoji_food_beverage_outlined,
      'bar': Icons.wine_bar_outlined,
      'beer': Icons.local_drink_outlined,
      'cocktail': Icons.local_bar_outlined,

      // Tiendas / shopping
      'shop': Icons.storefront_outlined,
      'store': Icons.store_outlined,
      'mall': Icons.shopping_bag_outlined,
      'market': Icons.local_grocery_store_outlined,

      // Salud y bienestar
      'spa': Icons.spa_outlined,
      'gym': Icons.fitness_center_outlined,
      'wellness': Icons.self_improvement_outlined,
      'pharmacy': Icons.local_pharmacy_outlined,

      // Entretenimiento
      'cinema': Icons.movie_outlined,
      'theater': Icons.theaters_outlined,
      'music': Icons.music_note_outlined,
      'karaoke': Icons.mic_outlined,
      'game': Icons.sports_esports_outlined,
      'bowling': Icons.sports_baseball_outlined,

      // Turismo / viajes
      'hotel': Icons.hotel_outlined,
      'bed': Icons.bed_outlined,
      'travel': Icons.flight_outlined,
      'beach': Icons.beach_access_outlined,
      'museum': Icons.account_balance_outlined,
      'park': Icons.park_outlined,

      // Servicios varios
      'beauty': Icons.brush_outlined,
      'hair': Icons.cut_outlined,
      'nails': Icons.brush_outlined,
      'car': Icons.directions_car_outlined,
      'bike': Icons.pedal_bike_outlined,
      'taxi': Icons.local_taxi_outlined,
      'bus': Icons.directions_bus_outlined,

      // Tecnología / oficinas
      'tech': Icons.devices_outlined,
      'computer': Icons.computer_outlined,
      'phone': Icons.phone_android_outlined,
      'office': Icons.apartment_outlined,
      'education': Icons.school_outlined,
      'book': Icons.menu_book_outlined,

      // Tiempo (por si mandas algo como "time")
      'time': Icons.access_time_outlined,
      'clock': Icons.schedule_outlined,
    };

    if (icon == null) return Icons.category_outlined;

    final normalized = icon.toLowerCase().trim();
    return iconMap[normalized] ?? Icons.category_outlined;
  }

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

  List<Promotion> _allPromos = [];
  bool _loadingPromos = true;
  String? _promosError;

  Future<void> _loadPromos() async {
    try {
      final promos = await _promoService.getAllActivePromos();
      setState(() {
        _allPromos = promos;
        _loadingPromos = false;
      });
      _debugIds();
    } catch (e) {
      setState(() {
        _promosError = e.toString();
        _loadingPromos = false;
        
      });
    }
  }
  void _debugIds() {
  for (final p in _allPromos.take(5)) {
    debugPrint('[PROMO] title="${p.title}" id=${p.id} valid=${p.hasValidBackendId} detailId=${p.detailId}');
  }
}
  // dentro de _PromotionsHomeScreenState
String? _clienteId;
  Future<void> _initFavorites() async {
  try {
    final usuario = await authService.getUser(); // <- ya lo usas en otros lados
    if (!mounted) return;
    final id = usuario?['_id'] as String?;
    if (id == null) return;

    setState(() => _clienteId = id);
    // Inicia el store con el clienteId (una vez)
    await context.read<FavoritesStore>().init(id);
  } catch (e) {
    // opcional: manejar error de auth/user
  }
}

  int _bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 👇 Carga las categorías al iniciar la pantalla
    _loadCategorias();
    _loadPromos();
    _loadCuponeras();
   
  }

  bool _didInitFavs = false;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (_didInitFavs) return;
  _didInitFavs = true;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final usuario = await authService.getUser(); // ya lo usas
      if (!mounted) return;
      final id = usuario?['_id'] as String?;
      if (id != null) {
        await context.read<FavoritesStore>().init(id);
      }
    } catch (_) {
      // opcional: manejar error
    }
  });
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

Future<void> _toggleFavorite(String promoId) async {
  try {
    print('negocioooId $promoId');
    await context.read<FavoritesStore>().toggle(promoId);
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo actualizar favorito')),
    );
  }
}

  List<Promotion> _applyFilters(List<Promotion> input) {
    List<Promotion> list = input;

    if (_selectedCities.isNotEmpty) {
      list = list.where((p) => _selectedCities.contains(p.city)).toList();
    }

    if (_query.isNotEmpty) {
      list = list.where((p) {
        final haystack =
            '${p.title} ${p.placeName} ${p.description} '
                    '${p.categories.join(" ")} ${p.tags.join(" ")}'
                .toLowerCase();
        return haystack.contains(_query);
      }).toList();
    }

    if (_selectedCats.isNotEmpty) {
      list = list.where((p) {
        // 2x1 sigue igual
        if (_selectedCats.contains('2x1') && !p.isTwoForOne) return false;

        // ✅ intersección con categorías: si hay alguna seleccionada en p.categories, pasa
        final sel = _selectedCats.difference({
          '2x1',
        }); // ignora el chip 2x1 en esta parte
        if (sel.isEmpty) return true;

        final promoCatsLower = p.categories.map((e) => e.toLowerCase()).toSet();
        final selLower = sel.map((e) => e.toLowerCase()).toSet();
        final intersects = promoCatsLower.intersection(selLower).isNotEmpty;
        return intersects;
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
        // ===== Categorías (dinámicas + 2x1) =====
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
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No se pudieron cargar categorías',
                          style: const TextStyle(color: Colors.redAccent),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    // chip especial "2x1"
                    CategoryChipLight(
                      label: '2x1',
                      icon: Icons.local_offer_outlined,
                      selected: _selectedCats.contains('2x1'),
                      onTap: () => _toggleCat('2x1'),
                    ),
                    // chips venidos del backend (solo activas)
                    ..._categorias.map((c) {
                      // Mapea tu string de icono si quieres (opcional)
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
        // Listas por tabs
        Expanded(
          child: _loadingPromos
              ? const Center(child: CircularProgressIndicator())
              : _promosError != null
              ? Center(child: Text("Error cargando promos: $_promosError"))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    PromosListLight(
                      promos: _applyFilters(_allPromos),
                      cardStyle: CardStyle.normal,
                     isFavorite: (p) => favs.isFav(p.id), 
                      onFavorite: (p) => _toggleFavorite(p.id), // 👈 OK
                    ),
                    // Dentro de _buildHomeBody() -> TabBarView(children: [...])
                    PromosListLight(
                      promos: _applyFilters(
                        _onlyToday(_allPromos),
                      ), // ✅ por día
                      cardStyle: CardStyle.normal,
                     isFavorite: (p) => favs.isFav(p.id), 
                    onFavorite: (p) => _toggleFavorite(p.id), // 👈 OK
                    ),

                    PromosListLight(
                      promos: _applyFilters(
                        _allPromos.where((p) => p.isFlash).toList(),
                      ),
                      cardStyle: CardStyle.flash,
                      isFavorite: (p) => favs.isFav(p.id), 
                      onFavorite: (p) => _toggleFavorite(p.id), // 👈 OK
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
    // ✅ usamos el store en vez de la variable local
    final favsStore = context.watch<FavoritesStore>();
    final favs = _allPromos.where((p) => favsStore.isFav(p.id)).toList();
    return FavoritesScreenLight(
      promos: favs,
      onUnfavorite: (p) => _toggleFavorite(p.id),
    );
  }

  if (_bottomIndex == 2) {
    return SearchScreenLight(
      all: _allPromos,
      isFavorite: (p) => context.watch<FavoritesStore>().isFav(p.id),
      onFavorite: (p) => _toggleFavorite(p.id),
    );
  }
  if (_bottomIndex == 3) { // o el índice que uses para "Cuponeras"
  print('object $_loadingCuponeras');
  if (_loadingCuponeras) {
    return const Center(child: CircularProgressIndicator());
  }
  if (_cuponerasError != null) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Error al cargar cuponeras', style: const TextStyle(color: Colors.redAccent)),
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


  return const CuponerasScreenLight(cuponeras: []);
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
                  onViewProfile: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreenLight(
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
