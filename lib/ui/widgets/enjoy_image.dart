import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:enjoy/ui/enjoy_colors.dart';

/// Imagen de red con **caché en disco + memoria** (cached_network_image).
///
/// Reemplaza a `Image.network` para que las imágenes NO se vuelvan a descargar
/// al navegar entre pantallas (ni al reabrir la app). Trae placeholder y
/// fallback coherentes con el tema.
class EnjoyImage extends StatelessWidget {
  const EnjoyImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholderIcon,
    this.errorWidget,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData? placeholderIcon;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    Widget img;
    if (url == null || url!.trim().isEmpty) {
      img = _fallback(ec);
    } else {
      img = CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => _placeholder(ec),
        errorWidget: (_, __, ___) => errorWidget ?? _fallback(ec),
      );
    }
    if (borderRadius != null) {
      img = ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }

  Widget _placeholder(EnjoyColors ec) => Container(
        width: width,
        height: height,
        color: ec.glass,
      );

  Widget _fallback(EnjoyColors ec) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [ec.iconGlassTop, ec.iconGlassBottom]),
        ),
        alignment: Alignment.center,
        child: Icon(
          placeholderIcon ?? Icons.image_outlined,
          color: ec.textMute,
          size: 22,
        ),
      );
}

/// Provider con caché para usar en `DecorationImage`/avatares.
ImageProvider enjoyImageProvider(String url) => CachedNetworkImageProvider(url);
