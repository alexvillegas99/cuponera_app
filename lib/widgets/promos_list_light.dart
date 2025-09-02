import 'package:flutter/material.dart';
import '../ui/palette.dart';
import '../models/promotion_models.dart';
import 'promo_card_light.dart';

class PromosListLight extends StatelessWidget {
  final List<Promotion> promos;
  final CardStyle cardStyle;
  final bool Function(Promotion) isFavorite;
  final void Function(Promotion) onFavorite;

  const PromosListLight({
    super.key,
    required this.promos,
    required this.cardStyle,
    required this.isFavorite,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (promos.isEmpty) {
      return const Center(child: Text('Sin promociones para mostrar', style: TextStyle(color: Palette.kMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
      itemCount: promos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => PromoCardLight(
        promo: promos[i],
        style: cardStyle,
        isFavorite: isFavorite(promos[i]),
        onTap: () {},
        onFavorite: () => onFavorite(promos[i]),
        onShare: () {},
      ),
    );
  }
}
