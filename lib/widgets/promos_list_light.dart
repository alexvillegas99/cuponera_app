// lib/widgets/promos_list_light.dart
import 'package:flutter/material.dart';
import '../models/promotion_models.dart';
import 'promo_card_light.dart';


typedef IsFav = bool Function(Promotion);
typedef OnFav = Future<void> Function(Promotion); // o: void Function(Promotion)

class PromosListLight extends StatelessWidget {
  final List<Promotion> promos;
  final CardStyle cardStyle;
  final IsFav isFavorite;
  final OnFav onFavorite;

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
      return const Center(child: Text('Sin promociones para mostrar'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
      itemCount: promos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = promos[i];
        return PromoCardLight(
          promo: p,
          style: cardStyle,
          isFavorite: isFavorite(p),
          onTap: () { /* navegar si quieres */ },
          // 👇 Puenteamos: la card espera VoidCallback (sin args),
          // y aquí le pasamos una lambda que llama tu onFavorite(p).
          onFavorite: () => onFavorite(p),
          onShare: () { /* compartir */ },
        );
      },
    );
  }
}
