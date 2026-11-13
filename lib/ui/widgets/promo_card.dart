import 'package:enjoy/ui/texto.dart';
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
    this.meta,
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

  /// Línea de datos prácticos (ciudad · categoría · horario · distancia).
  final String? meta;
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
                      boxShadow: ec.shadowAccent,
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
                        // Solo el favorito marcado lleva acento.
                        color: isFavorite ? ec.orange : Colors.white,
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
                    // Etiqueta sobre foto: negro mate legible; casi todas las
                    // promos son 2x1, así que en acento sería ruido.
                    decoration: BoxDecoration(
                      color: const Color(0xE61D1E21),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      discount!,
                      style: EnjoyTheme.heading(
                          size: 14, weight: FontWeight.w800, color: Colors.white),
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
                      nombreLegible(title),
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
                    if (meta != null && meta!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EnjoyTheme.body(
                            size: 11, color: Colors.white.withValues(alpha: .72)),
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


/// Oferta y línea de datos de una promoción, iguales en todas las listas:
/// subtítulo = la oferta; meta = ciudad · categoría · horario · distancia.
({String? oferta, String meta}) promoTextos(dynamic p, {String? distancia}) {
  final String place = (p.placeName ?? '').toString();
  final String title = (p.title ?? '').toString();
  final List cats = (p.categories ?? const []) as List;
  final oferta = title.trim().isNotEmpty && title.trim().toLowerCase() != place.trim().toLowerCase()
      ? title.trim()
      : null;
  // Lo corto primero (el horario puede ser largo y se recorta al final).
  final meta = [
    (p.city ?? '').toString(),
    distancia ?? '',
    cats.isNotEmpty ? cats.first.toString() : '',
    (p.scheduleLabel ?? '').toString(),
  ].where((e) => e.trim().isNotEmpty).join(' · ');
  return (oferta: oferta, meta: meta);
}
