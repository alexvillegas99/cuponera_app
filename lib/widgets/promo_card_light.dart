import 'package:enjoy/screens/clientes/comercio_detalle_mini_screen.dart';
import 'package:flutter/material.dart';
import '../ui/palette.dart';
import '../models/promotion_models.dart';
import 'chip_tiny_light.dart';
import 'info_tiny_light.dart';
import 'flash_countdown_light.dart';
import 'pill_light.dart';




enum CardStyle { normal, flash,compact }

class PromoCardLight extends StatelessWidget {
  final Promotion promo;
  final CardStyle style;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onShare;

  /// Distancia calculada con el GPS del cliente (ej. "1.2 km"). Si viene, se
  /// muestra como indicador junto a la ubicación.
  final String? distanceOverride;
  const PromoCardLight({
    super.key,
    required this.promo,
    required this.style,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    required this.onShare,
    this.distanceOverride,
  });

  

  @override
  Widget build(BuildContext context) {
    final isFlash = style == CardStyle.flash;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComercioDetalleMiniScreen(usuarioId: promo.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  // Fondo: imagen 16:9 que "cubre"
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final targetWidth = (constraints.maxWidth * dpr).round();

                      return AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          promo.coverUrl,
                          fit: BoxFit.cover,
                          cacheWidth: targetWidth,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(color: Palette.kField);
                          },
                          errorBuilder: (ctx, err, st) => Container(
                            color: Palette.kField,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Palette.kMuted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // LOGO (overlay)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _LogoBadge(url: promo.logoUrl),
                  ),

                  // Badge 2x1
                  if (promo.isTwoForOne)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Palette.kAccent, Palette.kAccentLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Palette.kAccent.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_offer_rounded, color: Colors.white, size: 11),
                            SizedBox(width: 4),
                            Text('2x1', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),

                  // Countdown Flash
                  if (isFlash)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: FlashCountdownLight(endAt: promo.endDate),
                    ),
                ],
              ),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          promo.placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Palette.kTitle,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (promo.rating > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star,
                          color: Palette.kAccentLight,
                          size: 18,
                        ),
                        Text(
                          promo.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Palette.kTitle),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promo.title,
                    style: const TextStyle(color: Palette.kSub),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    promo.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Palette.kMuted),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: [
                      for (final t in promo.tags.take(4)) ChipTinyLight(t),
                      if (promo.tags.length > 4)
                        ChipTinyLight('+${promo.tags.length - 4}'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      InfoTinyLight(
                        icon: Icons.schedule,
                        label: promo.scheduleLabel,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onFavorite,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isFavorite
                                ? Colors.redAccent.withOpacity(0.08)
                                : Palette.kField,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFavorite
                                  ? Colors.redAccent.withOpacity(0.25)
                                  : Palette.kBorder,
                            ),
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFavorite ? Colors.redAccent : Palette.kMuted,
                            size: 17,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onShare,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Palette.kField,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Palette.kBorder),
                          ),
                          child: const Icon(
                            Icons.ios_share,
                            color: Palette.kMuted,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Palette.kMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (promo.address?.isNotEmpty == true)
                              ? promo.address!
                              : promo.distanceLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: const TextStyle(color: Palette.kSub),
                        ),
                      ),
                      if (distanceOverride != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Palette.kAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me_rounded, size: 12, color: Palette.kAccent),
                              const SizedBox(width: 3),
                              Text(distanceOverride!,
                                  style: const TextStyle(
                                      color: Palette.kAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
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

class _LogoBadge extends StatelessWidget {
  final String url;
  const _LogoBadge({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.storefront_outlined,
          size: 20,
          color: Palette.kMuted,
        ),
      ),
    );
  }
}

class AdaptiveNetworkImage extends StatefulWidget {
  final String url;
  final double fallbackAspectRatio;
  final BoxFit fit;

  const AdaptiveNetworkImage({
    super.key,
    required this.url,
    this.fallbackAspectRatio = 16 / 9,
    this.fit = BoxFit.cover,
  });

  @override
  State<AdaptiveNetworkImage> createState() => _AdaptiveNetworkImageState();
}

class _AdaptiveNetworkImageState extends State<AdaptiveNetworkImage> {
  ImageStreamListener? _listener;
  double? _aspect;

  @override
  void initState() {
    super.initState();
    
    final stream = NetworkImage(widget.url).resolve(const ImageConfiguration());
    _listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (w > 0 && h > 0 && mounted) {
        setState(() => _aspect = w / h);
      }
    }, onError: (_, __) {});
    stream.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) {
      final stream = NetworkImage(
        widget.url,
      ).resolve(const ImageConfiguration());
      stream.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect ?? widget.fallbackAspectRatio;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = (constraints.maxWidth * dpr).round();
        return AspectRatio(
          aspectRatio: aspect,
          child: Image.network(
            widget.url,
            fit: widget.fit,
            cacheWidth: targetWidth,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(color: Palette.kField);
            },
            errorBuilder: (ctx, err, st) => Container(
              color: Palette.kField,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: Palette.kMuted,
              ),
            ),
          ),
        );
      },
    );
  }
}
