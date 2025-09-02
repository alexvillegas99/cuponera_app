import 'package:flutter/material.dart';
import '../ui/palette.dart';
import '../models/promotion_models.dart';
import 'chip_tiny_light.dart';
import 'info_tiny_light.dart';
import 'flash_countdown_light.dart';
import 'pill_light.dart';

enum CardStyle { normal, flash }

class PromoCardLight extends StatelessWidget {
  final Promotion promo;
  final CardStyle style;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  const PromoCardLight({
    super.key,
    required this.promo,
    required this.style,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final isFlash = style == CardStyle.flash;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.kBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen + badges
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              child: Stack(children: [
                AspectRatio(aspectRatio: 16 / 9, child: Image.network(promo.imageUrl, fit: BoxFit.cover)),
                Positioned(left: 10, top: 10, child: CircleAvatar(backgroundColor: Colors.white, backgroundImage: NetworkImage(promo.logoUrl), radius: 18)),
                if (promo.isTwoForOne) const Positioned(right: 10, top: 10, child: PillLight(label: '2x1', icon: Icons.local_offer)),
                if (isFlash) Positioned(right: 10, bottom: 10, child: FlashCountdownLight(endAt: promo.endDate)),
              ]),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(promo.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.star, color: Colors.amber.shade400, size: 18),
                  Text(promo.rating.toStringAsFixed(1), style: const TextStyle(color: Palette.kTitle)),
                ]),
                const SizedBox(height: 4),
                Text(promo.placeName, style: const TextStyle(color: Palette.kSub)),
                const SizedBox(height: 8),
                Text(promo.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.kMuted)),
                const SizedBox(height: 10),

                Wrap(spacing: 6, runSpacing: -6, children: [
                  for (final t in promo.tags.take(4)) ChipTinyLight(t),
                  if (promo.tags.length > 4) ChipTinyLight('+${promo.tags.length - 4}'),
                ]),
                const SizedBox(height: 12),

                Row(children: [
                  InfoTinyLight(icon: Icons.schedule, label: promo.scheduleLabel),
                  const Spacer(),
                  IconButton(
                    onPressed: onFavorite,
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.redAccent : Palette.kMuted),
                  ),
                  IconButton(onPressed: onShare, icon: const Icon(Icons.ios_share, color: Palette.kMuted)),
                ]),
                const SizedBox(height: 6),

                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.location_on_outlined, color: Palette.kMuted, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      (promo.address?.isNotEmpty == true) ? promo.address! : promo.distanceLabel,
                      maxLines: 2, overflow: TextOverflow.ellipsis, softWrap: true, style: const TextStyle(color: Palette.kSub),
                    ),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
