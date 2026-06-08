import 'package:flutter/material.dart';
import '../../models/promotion_models.dart';
import '../../ui/palette.dart';
import '../../widgets/promos_list_light.dart';
import '../../widgets/promo_card_light.dart';

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

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: Colors.redAccent,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sin favoritos aún',
            style: TextStyle(
              color: Palette.kTitle,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Guarda promociones para encontrarlas rápido',
            style: TextStyle(color: Palette.kMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.promos.isEmpty) {
      return _emptyState();
    }

    final list = _filtered;

    return Column(
      children: [
        // Buscador de favoritos
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            style: const TextStyle(color: Palette.kTitle),
            cursorColor: Palette.kAccent,
            decoration: InputDecoration(
              hintText: 'Buscar en favoritos…',
              hintStyle: const TextStyle(color: Palette.kMuted),
              prefixIcon:
                  const Icon(Icons.search, color: Palette.kMuted, size: 22),
              filled: true,
              fillColor: Palette.kField,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    'Sin resultados',
                    style: TextStyle(color: Palette.kMuted),
                  ),
                )
              : PromosListLight(
                  promos: list,
                  cardStyle: CardStyle.compact,
                  isFavorite: (_) => true,
                  onFavorite: (p) async => widget.onUnfavorite(p),
                ),
        ),
      ],
    );
  }
}
