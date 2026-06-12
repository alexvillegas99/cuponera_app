import 'package:enjoy/models/promotion_models.dart';
import 'package:enjoy/screens/clientes/comercio_detalle_mini_screen.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/services/promotions_service.dart';
import 'package:enjoy/state/favorites_store.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSelectedCityIdsKey = 'selected_city_ids_v1';
const _kSelectedProvinciasKey = 'selected_provincia_ids_v1';

/// Lista completa de promociones activas hoy (filtradas por la
/// ubicación elegida en el Home). Reusa [PromotionsService] con
/// `isToday: true`.
class PromosHoyScreen extends StatefulWidget {
  const PromosHoyScreen({super.key});

  @override
  State<PromosHoyScreen> createState() => _PromosHoyScreenState();
}

class _PromosHoyScreenState extends State<PromosHoyScreen> {
  final _svc = PromotionsService();
  final _authService = AuthService();
  final _scroll = ScrollController();

  List<Promotion> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _query = '';
  bool _ordenarCercania = false;
  bool _soloConCupon = false;
  bool _cargandoDisponibles = false;
  String _ordenNombre = 'none';
  double? _userLat;
  double? _userLng;
  final Set<String> _localesConCupon = {};

  Set<String> _provinciaIds = {};
  Set<String> _ciudadIds = {};

  bool get _filtrosActivos =>
      _ordenarCercania || _soloConCupon || _ordenNombre != 'none';

  List<Promotion> get _filtered {
    final q = _query.trim().toLowerCase();
    var list = q.isEmpty
        ? List<Promotion>.from(_items)
        : _items.where((p) {
            final haystack =
                '${p.title} ${p.placeName} ${p.description} '
                        '${p.categories.join(" ")} ${p.tags.join(" ")}'
                    .toLowerCase();
            return haystack.contains(q);
          }).toList();
    if (_ordenNombre != 'none') {
      String nombre(Promotion p) =>
          (p.placeName.isNotEmpty ? p.placeName : p.title).toLowerCase();
      list.sort(
        (a, b) => _ordenNombre == 'asc'
            ? nombre(a).compareTo(nombre(b))
            : nombre(b).compareTo(nombre(a)),
      );
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _provinciaIds = (prefs.getStringList(_kSelectedProvinciasKey) ?? [])
        .toSet();
    _ciudadIds = (prefs.getStringList(_kSelectedCityIdsKey) ?? []).toSet();
    await _load();
    _loadUserLocation();
  }

  Future<void> _load() async {
    if (_provinciaIds.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final feed = await _svc.loadFirst(
        provinciaIds: _provinciaIds.toList(),
        ciudadIds: _ciudadIds.isEmpty ? null : _ciudadIds.toList(),
        isToday: true,
        localIds: _soloConCupon ? _localesConCupon.toList() : null,
        lat: _ordenarCercania ? _userLat : null,
        lng: _ordenarCercania ? _userLng : null,
        force: true,
      );
      if (!mounted) return;
      setState(() {
        _items = feed.promos;
        _hasMore = feed.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 320 && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _provinciaIds.isEmpty) return;
    if (!mounted) return;
    setState(() => _loadingMore = true);
    try {
      final feed = await _svc.loadMore(
        provinciaIds: _provinciaIds.toList(),
        ciudadIds: _ciudadIds.isEmpty ? null : _ciudadIds.toList(),
        isToday: true,
        localIds: _soloConCupon ? _localesConCupon.toList() : null,
        lat: _ordenarCercania ? _userLat : null,
        lng: _ordenarCercania ? _userLng : null,
      );
      if (!mounted) return;
      setState(() {
        _items = feed.promos;
        _hasMore = feed.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
      });
    } catch (_) {}
  }

  double _distanciaA(Promotion promo) {
    if (promo.lat == null ||
        promo.lng == null ||
        _userLat == null ||
        _userLng == null) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
      _userLat!,
      _userLng!,
      promo.lat!,
      promo.lng!,
    );
  }

  Future<void> _cargarLocalesConCupon() async {
    final user = await _authService.getUser();
    final clienteId = user?['_id']?.toString();
    if (clienteId == null || clienteId.isEmpty) return;
    setState(() => _cargandoDisponibles = true);
    try {
      final ids = await CuponesService().localesDisponibles(clienteId);
      if (!mounted) return;
      setState(() {
        _localesConCupon
          ..clear()
          ..addAll(ids);
        _cargandoDisponibles = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoDisponibles = false);
    }
  }

  Future<void> _openFiltros() async {
    final ec = context.ec;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ec.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: SingleChildScrollView(
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
                Text(
                  'Filtros',
                  style: EnjoyTheme.heading(
                    size: 18,
                    weight: FontWeight.w800,
                    color: ec.text,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: ec.orange,
                  value: _ordenarCercania,
                  onChanged: _userLat == null
                      ? null
                      : (value) {
                          setState(() => _ordenarCercania = value);
                          setSheet(() {});
                        },
                  title: Text(
                    'Ordenar por cercanía',
                    style: EnjoyTheme.body(
                      size: 15,
                      weight: FontWeight.w600,
                      color: ec.text,
                    ),
                  ),
                  subtitle: Text(
                    _userLat == null
                        ? 'Activa la ubicación para usar este filtro'
                        : 'Muestra primero los locales más cercanos',
                    style: EnjoyTheme.body(size: 12, color: ec.textMute),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: ec.orange,
                  value: _soloConCupon,
                  onChanged: (value) async {
                    setState(() => _soloConCupon = value);
                    setSheet(() {});
                    if (value && _localesConCupon.isEmpty) {
                      await _cargarLocalesConCupon();
                      if (mounted) setSheet(() {});
                    }
                  },
                  title: Text(
                    'Solo con cupón disponible',
                    style: EnjoyTheme.body(
                      size: 15,
                      weight: FontWeight.w600,
                      color: ec.text,
                    ),
                  ),
                  subtitle: Text(
                    'Locales donde te queda un canje sin usar',
                    style: EnjoyTheme.body(size: 12, color: ec.textMute),
                  ),
                ),
                if (_cargandoDisponibles)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ec.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Buscando tus cupones…',
                          style: EnjoyTheme.body(size: 12, color: ec.textMute),
                        ),
                      ],
                    ),
                  ),
                const EnjoyDivider(height: 22),
                const FieldLabel('Ordenar por nombre'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in const [
                      ('none', 'Por defecto', Icons.clear_all_rounded),
                      ('asc', 'A → Z', Icons.arrow_upward_rounded),
                      ('desc', 'Z → A', Icons.arrow_downward_rounded),
                    ])
                      Pill(
                        option.$2,
                        icon: option.$3,
                        variant: _ordenNombre == option.$1
                            ? PillVariant.orange
                            : PillVariant.glass,
                        onTap: () {
                          setState(() => _ordenNombre = option.$1);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: EnjoyButton(
                        label: 'Limpiar',
                        variant: EnjoyButtonVariant.ghost,
                        onPressed: () {
                          setState(() {
                            _ordenarCercania = false;
                            _soloConCupon = false;
                            _ordenNombre = 'none';
                          });
                          Navigator.pop(sheetContext);
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnjoyButton(
                        label: 'Aplicar',
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final favs = context.watch<FavoritesStore>();

    return EnjoyScaffold(
      appBar: const EnjoyAppBar(title: 'Promos de hoy'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: EnjoyTheme.body(color: ec.text),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, local…',
                      hintStyle: EnjoyTheme.body(color: ec.textMute),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: ec.textMute,
                      ),
                      filled: true,
                      fillColor: ec.glass,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: ec.stroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: ec.stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: ec.orange),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GlassIconButton(
                  icon: Icons.tune_rounded,
                  accent: _filtrosActivos,
                  size: 48,
                  onTap: _openFiltros,
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(ec, favs)),
        ],
      ),
    );
  }

  Widget _buildBody(EnjoyColors ec, FavoritesStore favs) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: ec.orange));
    }
    if (_provinciaIds.isEmpty) {
      return _empty(
        ec,
        Icons.location_off_rounded,
        'Elige una provincia',
        'Selecciona tu provincia desde el Home para ver promos del día.',
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return _empty(
        ec,
        Icons.today_rounded,
        'Sin promos para hoy',
        'Vuelve mañana o explora todas las promociones desde Buscar.',
      );
    }
    return RefreshIndicator(
      color: ec.orange,
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
        itemCount: list.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          if (i >= list.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ec.orange,
                  ),
                ),
              ),
            );
          }
          final p = list[i];
          final distance = _distanciaA(p);
          final distanceLabel = distance.isFinite
              ? '${(distance / 1000).toStringAsFixed(1)} km'
              : null;
          final cat = p.categories.isNotEmpty ? p.categories.first : p.city;
          final subtitle = [
            distanceLabel,
            cat,
          ].where((value) => value != null && value.isNotEmpty).join(' · ');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PromoCard(
              title: p.placeName.isNotEmpty ? p.placeName : p.title,
              subtitle: subtitle.isEmpty ? p.title : subtitle,
              imageUrl: p.coverUrl,
              discount: p.isTwoForOne ? '2x1' : null,
              tieneFlash: p.tieneFlash,
              isFavorite: favs.isFav(p.id),
              onFavorite: () => context.read<FavoritesStore>().toggle(p.id),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ComercioDetalleMiniScreen(usuarioId: p.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(EnjoyColors ec, IconData icon, String title, String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: ec.textMute),
            const SizedBox(height: 12),
            Text(
              title,
              style: EnjoyTheme.heading(
                size: 17,
                weight: FontWeight.w800,
                color: ec.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: EnjoyTheme.body(color: ec.textSoft),
            ),
          ],
        ),
      ),
    );
  }
}
