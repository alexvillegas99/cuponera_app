import 'package:flutter/material.dart';
import '../ui/palette.dart';
import '../models/promotion_models.dart';
import 'chip_tiny_light.dart';
import 'info_tiny_light.dart';
import 'flash_countdown_light.dart';
import 'pill_light.dart';
import '../ui/card_style.dart'; // ajusta el path según tu estructura




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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen + badges
            // Imagen + badges (CON LOGO), usando AdaptiveNetworkImage
            // Imagen + badges (CON LOGO)
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
                          promo.imageUrl,
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
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: PillLight(label: '2x1', icon: Icons.local_offer),
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                        Icon(
                          Icons.star,
                          color: Colors.amber.shade400,
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
                      IconButton(
                        onPressed: onFavorite,
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.redAccent : Palette.kMuted,
                        ),
                      ),
                      IconButton(
                        onPressed: onShare,
                        icon: const Icon(
                          Icons.ios_share,
                          color: Palette.kMuted,
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
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Palette.kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.image_not_supported_outlined,
          size: 18,
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
