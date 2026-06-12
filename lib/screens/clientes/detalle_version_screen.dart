import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import '../../services/versiones_service.dart';
import 'comercio_detalle_mini_screen.dart';
import 'mapa_version_screen.dart';

class DetalleVersionScreen extends StatefulWidget {
  final String versionId;
  final Map<String, dynamic> versionData;

  const DetalleVersionScreen({
    super.key,
    required this.versionId,
    required this.versionData,
  });

  @override
  State<DetalleVersionScreen> createState() => _DetalleVersionScreenState();
}

class _DetalleVersionScreenState extends State<DetalleVersionScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _locales = [];

  @override
  void initState() {
    super.initState();
    _fetchLocales();
  }

  Future<void> _fetchLocales() async {
    try {
      final result = await VersionesService.listarLocales(widget.versionId);
      debugPrint('[MAPA] Total locales recibidos: ${result.length}');
      for (final l in result) {
        final nombre = l['detallePromocion']?['placeName'] ?? l['nombre'] ?? '?';
        final ub = l['ubicacion'];
        debugPrint('[MAPA] Local: $nombre | ubicacion: $ub');
      }
      if (!mounted) return;
      setState(() {
        _locales = result;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[MAPA] Error al cargar locales: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ─── Header card ───────────────────────────────────────────

  Widget _buildHeaderCard(EnjoyColors ec) {
    final nombre = widget.versionData['nombre']?.toString() ?? 'Membresía';
    final precio = widget.versionData['precio']?.toString() ?? '0.00';
    final descripcion = widget.versionData['descripcion']?.toString() ?? '';
    final ciudades = widget.versionData['ciudadesDisponibles'];

    return GlassCard(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(Icons.card_giftcard, accent: true, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: EnjoyTheme.heading(
                          size: 18, weight: FontWeight.w800, color: ec.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$$precio',
                      style: EnjoyTheme.heading(
                          size: 22,
                          weight: FontWeight.w800,
                          color: ec.orangeSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (descripcion.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              descripcion,
              style: EnjoyTheme.body(size: 14, height: 1.5, color: ec.textSoft),
            ),
          ],
          if (ciudades is List && ciudades.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: (ciudades).map<Widget>((c) {
                return Pill(
                  c.toString(),
                  variant: PillVariant.glass,
                  icon: Icons.location_on_outlined,
                  dense: true,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Locales list ──────────────────────────────────────────

  Widget _buildRatingStars(EnjoyColors ec, double rating) {
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.5;
    final emptyStars = 5 - fullStars - (hasHalf ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(fullStars, (_) {
          return Icon(Icons.star, color: ec.orange, size: 16);
        }),
        if (hasHalf) Icon(Icons.star_half, color: ec.orange, size: 16),
        ...List.generate(emptyStars, (_) {
          return Icon(Icons.star_border,
              color: ec.orange.withValues(alpha: 0.4), size: 16);
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: EnjoyTheme.body(
              size: 12, weight: FontWeight.w600, color: ec.textMute),
        ),
      ],
    );
  }

  Widget _buildLocalCard(EnjoyColors ec, Map<String, dynamic> local) {
    final detalle = local['detallePromocion'] as Map<String, dynamic>? ?? {};
    final placeName = detalle['placeName']?.toString() ?? 'Local';
    final title = detalle['title']?.toString() ?? '';
    final logoUrl = detalle['logoUrl']?.toString() ?? '';
    final rating = (detalle['rating'] is num)
        ? (detalle['rating'] as num).toDouble()
        : 0.0;
    final ciudades = local['ciudades'];

    final leading = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: ec.iconGlassGradient,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ec.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.isNotEmpty
          ? Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.storefront,
                color: ec.textMute,
                size: 26,
              ),
            )
          : Icon(
              Icons.storefront,
              color: ec.textMute,
              size: 26,
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        radius: 16,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ComercioDetalleMiniScreen(usuarioId: local['_id']),
            ),
          );
        },
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    placeName,
                    style: EnjoyTheme.heading(size: 15, color: ec.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: EnjoyTheme.body(size: 13, color: ec.textMute),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  _buildRatingStars(ec, rating),
                  if (ciudades is List && ciudades.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      (ciudades).join(', '),
                      style: EnjoyTheme.body(size: 12, color: ec.textMute),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: ec.textMute, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalesSection(EnjoyColors ec) {
    final ciudades = widget.versionData['ciudadesDisponibles'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: SectionTitle('Locales disponibles')),
            if (ciudades is List && ciudades.isNotEmpty)
              Pill((ciudades).join(' · '), variant: PillVariant.glass),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: CircularProgressIndicator(color: ec.orange),
            ),
          )
        else if (_locales.isEmpty)
          GlassCard(
            child: Center(
              child: Text(
                'No hay locales disponibles para esta version.',
                style: EnjoyTheme.body(size: 14, color: ec.textMute),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ..._locales.map((l) => _buildLocalCard(ec, l)),
      ],
    );
  }

  // ─── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final nombre =
        widget.versionData['nombre']?.toString() ?? 'Detalle Membresía';

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Detalle Membresía'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(ec),
            const SizedBox(height: 24),
            _buildLocalesSection(ec),
            // CTA al final del contenido (altura normal, no se estira).
            const SizedBox(height: 22),
            EnjoyButton(
              label: 'Ver en mapa',
              icon: Icons.place_outlined,
              variant: EnjoyButtonVariant.ghost,
              onPressed: _loading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapaVersionScreen(
                            versionNombre: nombre,
                            locales: _locales,
                          ),
                        ),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}
