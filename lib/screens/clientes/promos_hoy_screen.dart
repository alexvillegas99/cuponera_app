import 'package:enjoy/models/promotion_models.dart';
import 'package:enjoy/screens/clientes/comercio_detalle_mini_screen.dart';
import 'package:enjoy/services/promotions_service.dart';
import 'package:enjoy/state/favorites_store.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
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
  final _scroll = ScrollController();

  List<Promotion> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _query = '';

  Set<String> _provinciaIds = {};
  Set<String> _ciudadIds = {};

  List<Promotion> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((p) {
      return p.title.toLowerCase().contains(q) ||
          p.placeName.toLowerCase().contains(q) ||
          (p.categories.isNotEmpty &&
              p.categories.first.toLowerCase().contains(q));
    }).toList();
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
    _provinciaIds =
        (prefs.getStringList(_kSelectedProvinciasKey) ?? []).toSet();
    _ciudadIds = (prefs.getStringList(_kSelectedCityIdsKey) ?? []).toSet();
    await _load();
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
    if (pos.pixels >= pos.maxScrollExtent - 320 &&
        !_loadingMore &&
        _hasMore) {
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
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: EnjoyTheme.body(color: ec.text),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, local…',
                hintStyle: EnjoyTheme.body(color: ec.textMute),
                prefixIcon: Icon(Icons.search_rounded, color: ec.textMute),
                filled: true,
                fillColor: ec.glass,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      return _empty(ec, Icons.location_off_rounded,
          'Elige una provincia',
          'Selecciona tu provincia desde el Home para ver promos del día.');
    }
    final list = _filtered;
    if (list.isEmpty) {
      return _empty(ec, Icons.today_rounded,
          'Sin promos para hoy',
          'Vuelve mañana o explora todas las promociones desde Buscar.');
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
                      strokeWidth: 2, color: ec.orange),
                ),
              ),
            );
          }
          final p = list[i];
          final cat = p.categories.isNotEmpty ? p.categories.first : p.city;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PromoCard(
              title: p.placeName.isNotEmpty ? p.placeName : p.title,
              subtitle: cat.isEmpty ? p.title : cat,
              imageUrl: p.coverUrl,
              discount: p.isTwoForOne ? '2x1' : null,
              tieneFlash: p.tieneFlash,
              isFavorite: favs.isFav(p.id),
              onFavorite: () =>
                  context.read<FavoritesStore>().toggle(p.id),
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
            Text(title,
                style: EnjoyTheme.heading(
                    size: 17, weight: FontWeight.w800, color: ec.text)),
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
