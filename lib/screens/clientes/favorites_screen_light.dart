import 'package:flutter/material.dart';
import '../../models/promotion_models.dart';
import '../../ui/palette.dart';
import '../../widgets/promos_list_light.dart';
import '../../widgets/promo_card_light.dart';

class FavoritesScreenLight extends StatelessWidget {
  final List<Promotion> promos;
  final void Function(Promotion) onUnfavorite;

  const FavoritesScreenLight({
    super.key,
    required this.promos,
    required this.onUnfavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (promos.isEmpty) {
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

    return PromosListLight(
      promos: promos,
      cardStyle: CardStyle.compact,
      isFavorite: (_) => true,
      onFavorite: (p) async => onUnfavorite(p),
    );
  }
}
