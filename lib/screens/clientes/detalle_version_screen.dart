import 'package:flutter/material.dart';
import '../../ui/palette.dart';
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
      print('[MAPA] Total locales recibidos: ${result.length}');
      for (final l in result) {
        final nombre = l['detallePromocion']?['placeName'] ?? l['nombre'] ?? '?';
        final ub = l['ubicacion'];
        print('[MAPA] Local: $nombre | ubicacion: $ub');
      }
      if (!mounted) return;
      setState(() {
        _locales = result;
        _loading = false;
      });
    } catch (e) {
      print('[MAPA] Error al cargar locales: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ─── Build helpers ──────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Palette.kAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Palette.kAccent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Palette.kTitle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // ─── Header card ───────────────────────────────────────────

  Widget _buildHeaderCard() {
    final nombre = widget.versionData['nombre']?.toString() ?? 'Cuponera';
    final precio = widget.versionData['precio']?.toString() ?? '0.00';
    final descripcion = widget.versionData['descripcion']?.toString() ?? '';
    final ciudades = widget.versionData['ciudadesDisponibles'];

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Palette.kAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: Palette.kAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Palette.kTitle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$$precio',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: Palette.kAccent,
                        ),
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
                style: const TextStyle(
                  color: Palette.kMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            if (ciudades is List && ciudades.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: (ciudades as List).map<Widget>((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.kPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Palette.kPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          c.toString(),
                          style: const TextStyle(
                            color: Palette.kPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Locales list ──────────────────────────────────────────

  Widget _buildRatingStars(double rating) {
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.5;
    final emptyStars = 5 - fullStars - (hasHalf ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(fullStars, (_) {
          return const Icon(Icons.star, color: Palette.kAccent, size: 16);
        }),
        if (hasHalf)
          const Icon(Icons.star_half, color: Palette.kAccent, size: 16),
        ...List.generate(emptyStars, (_) {
          return Icon(Icons.star_border,
              color: Palette.kAccent.withOpacity(0.4), size: 16);
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color: Palette.kMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLocalCard(Map<String, dynamic> local) {
    final detalle =
        local['detallePromocion'] as Map<String, dynamic>? ?? {};
    final placeName = detalle['placeName']?.toString() ?? 'Local';
    final title = detalle['title']?.toString() ?? '';
    final logoUrl = detalle['logoUrl']?.toString() ?? '';
    final rating = (detalle['rating'] is num)
        ? (detalle['rating'] as num).toDouble()
        : 0.0;
    final ciudades = local['ciudades'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ComercioDetalleMiniScreen(usuarioId: local['_id']),
            ),
          );
        },
        child: _card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Logo / avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Palette.kBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logoUrl.isNotEmpty
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.storefront,
                            color: Palette.kMuted,
                            size: 26,
                          ),
                        )
                      : const Icon(
                          Icons.storefront,
                          color: Palette.kMuted,
                          size: 26,
                        ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Palette.kTitle,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Palette.kMuted,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      _buildRatingStars(rating),
                      if (ciudades is List && ciudades.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          (ciudades as List).join(', '),
                          style: const TextStyle(
                            color: Palette.kMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Palette.kMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.storefront, 'Locales disponibles'),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Palette.kAccent),
            ),
          )
        else if (_locales.isEmpty)
          _card(
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No hay locales disponibles para esta version.',
                  style: TextStyle(color: Palette.kMuted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          ..._locales.map(_buildLocalCard),
      ],
    );
  }

  // ─── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nombre =
        widget.versionData['nombre']?.toString() ?? 'Detalle Cuponera';

    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        actions: [
          if (!_loading)
            IconButton(
              tooltip: 'Ver en mapa',
              icon: const Icon(Icons.map_outlined),
              onPressed: () {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 24),
            _buildLocalesSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
