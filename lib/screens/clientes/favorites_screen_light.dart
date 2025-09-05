import 'package:enjoy/widgets/promo_card_light.dart';
import 'package:flutter/material.dart';
import '../../models/promotion_models.dart';
import '../../ui/palette.dart';

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
      return const Center(child: Text('Aún no tienes favoritos', style: TextStyle(color: Palette.kMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: promos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => PromoCardLight(
        promo: promos[i],
        style: CardStyle.normal,
        isFavorite: true,
        onTap: () {},
        onFavorite: () => onUnfavorite(promos[i]),
        onShare: () {},
      ),
    );
  }
}
