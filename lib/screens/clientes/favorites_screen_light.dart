import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import '../../models/promotion_models.dart';
import '../../screens/clientes/comercio_detalle_mini_screen.dart';

class FavoritesScreenLight extends StatefulWidget {
  final List<Promotion> promos;
  final void Function(Promotion) onUnfavorite;

  const FavoritesScreenLight({
    super.key,
    required this.promos,
    required this.onUnfavorite,
  });

  @override
  State<FavoritesScreenLight> createState() => _FavoritesScreenLightState();
}

class _FavoritesScreenLightState extends State<FavoritesScreenLight> {
  String _query = '';

  List<Promotion> get _filtered {
    if (_query.isEmpty) return widget.promos;
    final q = _query.toLowerCase();
    return widget.promos.where((p) {
      final hay =
          '${p.title} ${p.placeName} ${p.description} ${p.categories.join(' ')} ${p.tags.join(' ')}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _openDetalle(Promotion p) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComercioDetalleMiniScreen(usuarioId: p.id),
      ),
    );
  }

  Widget _emptyState(EnjoyColors ec) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ec.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: ec.orange.withValues(alpha: 0.28)),
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              color: ec.orangeSoft,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Sin favoritos aún',
            style: EnjoyTheme.heading(size: 15, color: ec.text),
          ),
          const SizedBox(height: 4),
          Text(
            'Guarda promociones para encontrarlas rápido',
            style: EnjoyTheme.body(size: 12, color: ec.textMute),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;

    if (widget.promos.isEmpty) {
      return _emptyState(ec);
    }

    final list = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título + buscador de favoritos
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Favoritos', style: EnjoyTheme.heading(size: 20, color: ec.text)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            style: EnjoyTheme.body(size: 14, color: ec.text),
            cursorColor: ec.orange,
            decoration: const InputDecoration(
              hintText: 'Buscar en favoritos…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    'Sin resultados',
                    style: EnjoyTheme.body(size: 13, color: ec.textMute),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return PromoCard(
                      title: p.placeName.isNotEmpty ? p.placeName : p.title,
                      subtitle: p.title,
                      imageUrl: p.coverUrl,
                      topBadge: p.categories.isNotEmpty ? p.categories.first : null,
                      discount: p.isTwoForOne ? '2x1' : null,
                      isFavorite: true,
                      onFavorite: () => widget.onUnfavorite(p),
                      onTap: () => _openDetalle(p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
