import 'package:flutter/material.dart';
import '../models/promotion_models.dart';
import '../ui/palette.dart';
import 'promo_card_light.dart';
import '../screens/clientes/comercio_detalle_mini_screen.dart';

typedef IsFav = bool Function(Promotion);
typedef OnFav = Future<void> Function(Promotion);

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
      return const Center(
        child: Text(
          'Sin promociones para mostrar',
          style: TextStyle(color: Palette.kMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
      itemCount: promos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = promos[i];

        // 🔹 COMPACT
        if (cardStyle == CardStyle.compact) {
          return _PromoCompactTile(
            promo: p,
            isFavorite: isFavorite(p),
            onFavorite: () => onFavorite(p),
          );
        }

        // 🔹 NORMAL / FLASH
        return PromoCardLight(
          promo: p,
          style: cardStyle,
          isFavorite: isFavorite(p),
          onTap: () {},
          onFavorite: () => onFavorite(p),
          onShare: () {},
        );
      },
    );
  }
}

/// =======================================================================
/// 🔹 CARD COMPACTA
/// =======================================================================

class _PromoCompactTile extends StatelessWidget {
  final Promotion promo;
  final bool isFavorite;
  final VoidCallback onFavorite;

  const _PromoCompactTile({
    required this.promo,
    required this.isFavorite,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComercioDetalleMiniScreen(
              usuarioId: promo.id,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.kBorder),
        ),
        child: Row(
          children: [
            // Imagen pequeña
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                promo.imageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: Palette.kField,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: Palette.kMuted,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promo.placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Palette.kTitle,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    promo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Palette.kMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (promo.isTwoForOne)
                    const Text(
                      '2x1 disponible',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Palette.kAccent,
                      ),
                    ),
                ],
              ),
            ),

            // Favorito
            IconButton(
              onPressed: onFavorite,
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.redAccent : Palette.kMuted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
