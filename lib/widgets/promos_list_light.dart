import 'package:flutter/material.dart';
import '../ui/enjoy_dark.dart';
import '../models/promotion_models.dart';
import '../ui/palette.dart';
import '../utils/distancia.dart';
import 'promo_card_light.dart';
import '../screens/clientes/comercio_detalle_mini_screen.dart';

typedef IsFav = bool Function(Promotion);
typedef OnFav = Future<void> Function(Promotion);

class PromosListLight extends StatelessWidget {
  final List<Promotion> promos;
  final CardStyle cardStyle;
  final IsFav isFavorite;
  final OnFav onFavorite;
  final double? userLat;
  final double? userLng;

  const PromosListLight({
    super.key,
    required this.promos,
    required this.cardStyle,
    required this.isFavorite,
    required this.onFavorite,
    this.userLat,
    this.userLng,
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
                color: Palette.kAccent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_activity_outlined,
                color: Palette.kAccent,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Sin promociones',
              style: TextStyle(
                color: ED.text,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No hay resultados para los filtros seleccionados',
              style: TextStyle(color: ED.mute, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: promos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = promos[i];

        // 🔹 COMPACT
        if (cardStyle == CardStyle.compact) {
          return _PromoCompactTile(
            promo: p,
            isFavorite: isFavorite(p),
            onFavorite: () => onFavorite(p),
            distance: distanciaLabel(userLat, userLng, p.lat, p.lng),
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
          distanceOverride:
              distanciaLabel(userLat, userLng, p.lat, p.lng),
        );
      },
    );
  }
}

/// =======================================================================
/// 🔹 CARD COMPACTA — Enterprise redesign
/// =======================================================================

class _PromoCompactTile extends StatelessWidget {
  final Promotion promo;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final String? distance;

  const _PromoCompactTile({
    required this.promo,
    required this.isFavorite,
    required this.onFavorite,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final location = (promo.address?.isNotEmpty == true)
        ? promo.address!
        : promo.city;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        // Cierra el teclado y libera el foco del buscador para que no se
        // re-enfoque (autofocus) al volver al home.
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComercioDetalleMiniScreen(usuarioId: promo.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ED.cardSolid,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Imagen con logo overlay ──────────────────────────
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      promo.coverUrl,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : Container(color: ED.field),
                      errorBuilder: (_, __, ___) => Container(
                        width: 90,
                        height: 90,
                        color: ED.field,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: ED.mute,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Flash badge
                  if (promo.isFlash)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              'Flash',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Logo badge — esquina inferior derecha
                  if (promo.logoUrl.isNotEmpty)
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          promo.logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.storefront_outlined,
                            size: 14,
                            color: ED.mute,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // ── Contenido ────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          promo.placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ED.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (promo.rating > 0) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.star_rounded,
                          color: Palette.kAccentLight,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          promo.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: ED.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Título promo
                  Text(
                    promo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: ED.mute),
                  ),

                  const SizedBox(height: 7),

                  // Badge 2x1
                  if (promo.isTwoForOne)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Palette.kAccent, Palette.kAccentLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Palette.kAccent.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_offer_rounded,
                              color: Colors.white,
                              size: 10,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '2x1 disponible',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Horario
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: ED.mute,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          promo.scheduleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ED.mute,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Ubicación + favorito
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: ED.mute,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ED.mute,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (distance != null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.near_me_rounded, size: 11, color: Palette.kAccent),
                        const SizedBox(width: 2),
                        Text(distance!,
                            style: const TextStyle(
                                color: Palette.kAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onFavorite,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isFavorite
                                ? Colors.redAccent.withOpacity(0.08)
                                : ED.field,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isFavorite
                                  ? Colors.redAccent.withOpacity(0.25)
                                  : ED.border,
                            ),
                          ),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite ? Colors.redAccent : ED.mute,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
