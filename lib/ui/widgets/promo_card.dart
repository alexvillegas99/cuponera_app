import 'package:flutter/material.dart';

import 'package:enjoy/ui/enjoy_colors.dart';
import 'package:enjoy/ui/enjoy_theme.dart';
import 'package:enjoy/ui/widgets/enjoy_widgets.dart';
import 'package:enjoy/ui/widgets/enjoy_image.dart';

/// Tarjeta de promoción con imagen, overlay, badge de descuento y contenido
/// inferior (`.promo` de la propuesta).
class PromoCard extends StatelessWidget {
  const PromoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.discount,
    this.topBadge,
    this.bottomPill,
    this.height = 152,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.tint,
    this.tieneFlash = false,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;

  /// Texto del badge de descuento (ej. "-40%", "2x1").
  final String? discount;

  /// Pill superior izquierda (ej. categoría).
  final String? topBadge;

  /// Pill inferior derecha (ej. "Canje disponible").
  final Widget? bottomPill;
  final double height;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final Color? tint;

  /// El local tiene una promoción flash activa → muestra indicador "⚡ Flash".
  final bool tieneFlash;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final accent = tint ?? ec.orange;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagen (con caché) o degradado de relleno
              if (hasImage)
                EnjoyImage(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: _placeholder(ec, accent),
                )
              else
                _placeholder(ec, accent),

              // Overlay para legibilidad
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF080F1C).withValues(alpha: 0),
                      const Color(0xFF080F1C).withValues(alpha: .92),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
              ),

              if (topBadge != null)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Pill(topBadge!, dense: true),
                ),

              // Indicador: el local tiene una promoción flash activa.
              if (tieneFlash)
                Positioned(
                  left: 12,
                  top: topBadge != null ? 46 : 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: ec.accentGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: ec.orange.withValues(alpha: .45),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded,
                            color: ec.onAccent, size: 12),
                        const SizedBox(width: 3),
                        Text('Flash',
                            style: EnjoyTheme.heading(
                                size: 11, color: ec.onAccent)),
                      ],
                    ),
                  ),
                ),

              if (onFavorite != null)
                Positioned(
                  right: 12,
                  top: 12,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: ec.glassStrong,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: ec.stroke),
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: ec.orange,
                      ),
                    ),
                  ),
                ),

              if (discount != null)
                Positioned(
                  right: 13,
                  top: onFavorite != null ? 52 : 13,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: ec.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: ec.orange.withValues(alpha: .5),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Text(
                      discount!,
                      style: EnjoyTheme.heading(
                          size: 15, weight: FontWeight.w800, color: ec.onAccent),
                    ),
                  ),
                ),

              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Siempre blanco: va sobre la foto + overlay oscuro,
                      // independiente del tema (claro/oscuro).
                      style: EnjoyTheme.heading(size: 16, color: Colors.white),
                    ),
                    if (subtitle != null || bottomPill != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (subtitle != null)
                            Expanded(
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: EnjoyTheme.body(
                                    size: 12,
                                    color: Colors.white
                                        .withValues(alpha: .85)),
                              ),
                            ),
                          if (bottomPill != null) ...[
                            const SizedBox(width: 8),
                            bottomPill!,
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(EnjoyColors ec, Color accent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ec.iconGlassTop, ec.iconGlassBottom],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.6, -0.4),
        child: Container(
          width: 140,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [accent.withValues(alpha: .35), accent.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
