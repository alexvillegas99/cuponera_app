import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import '../../ui/palette.dart';
import 'comercio_detalle_mini_screen.dart';

class MapaVersionScreen extends StatefulWidget {
  final String versionNombre;
  final List<Map<String, dynamic>> locales;

  const MapaVersionScreen({
    super.key,
    required this.versionNombre,
    required this.locales,
  });

  @override
  State<MapaVersionScreen> createState() => _MapaVersionScreenState();
}

class _MapaVersionScreenState extends State<MapaVersionScreen> {
  final MapController _mapController = MapController();
  Map<String, dynamic>? _selectedLocal;

  List<Map<String, dynamic>> get _localesConUbicacion {
    final result = widget.locales.where((l) {
      final ub = l['ubicacion'];
      return ub != null && ub['lat'] != null && ub['lng'] != null;
    }).toList();
    print('[MAPA] Locales totales: ${widget.locales.length} | Con ubicacion: ${result.length}');
    return result;
  }

  LatLng get _center {
    final lista = _localesConUbicacion;
    if (lista.isEmpty) return const LatLng(-1.8312, -78.1834); // Ecuador centro
    final lats = lista.map((l) => (l['ubicacion']['lat'] as num).toDouble());
    final lngs = lista.map((l) => (l['ubicacion']['lng'] as num).toDouble());
    return LatLng(
      lats.reduce((a, b) => a + b) / lats.length,
      lngs.reduce((a, b) => a + b) / lngs.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locales = _localesConUbicacion;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        title: Text(
          widget.versionNombre,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '${locales.length} locales',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
      body: locales.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 52, color: Palette.kMuted),
                  SizedBox(height: 12),
                  Text(
                    'Ningún local tiene ubicación registrada aún.',
                    style: TextStyle(color: Palette.kMuted, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 14.5,
                    onTap: (_, __) => setState(() => _selectedLocal = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ecuenjoy.enjoy',
                    ),
                    MarkerLayer(
                      markers: locales.map((local) {
                        final ub = local['ubicacion'];
                        final lat = (ub['lat'] as num).toDouble();
                        final lng = (ub['lng'] as num).toDouble();
                        final detalle =
                            local['detallePromocion'] as Map<String, dynamic>? ??
                                {};
                        final logoUrl = detalle['logoUrl']?.toString() ?? '';
                        final isSelected = _selectedLocal == local;

                        return Marker(
                          point: LatLng(lat, lng),
                          width: 60,
                          height: 72,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedLocal = local);
                              _mapController.move(LatLng(lat, lng), 15);
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: isSelected ? 54 : 44,
                                  height: isSelected ? 54 : 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Palette.kAccent
                                          : Palette.kPrimary,
                                      width: isSelected ? 3 : 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.22),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: logoUrl.isNotEmpty
                                      ? Image.network(
                                          logoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.storefront,
                                            color: Palette.kPrimary,
                                            size: 22,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.storefront,
                                          color: Palette.kPrimary,
                                          size: 22,
                                        ),
                                ),
                                // Punta del pin
                                CustomPaint(
                                  size: const Size(14, 10),
                                  painter: _PinTailPainter(
                                    color: isSelected
                                        ? Palette.kAccent
                                        : Palette.kPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Atribución OSM (requerida por los términos de uso)
                Positioned(
                  bottom: _selectedLocal != null ? 120 : 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ),
                ),

                // Tarjeta del local seleccionado
                if (_selectedLocal != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _SelectedLocalCard(
                      local: _selectedLocal!,
                      onClose: () => setState(() => _selectedLocal = null),
                      onVerDetalle: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComercioDetalleMiniScreen(
                              usuarioId: _selectedLocal!['_id'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

// ─── Tarjeta de local seleccionado ─────────────────────────────────────────

class _SelectedLocalCard extends StatelessWidget {
  final Map<String, dynamic> local;
  final VoidCallback onClose;
  final VoidCallback onVerDetalle;

  const _SelectedLocalCard({
    required this.local,
    required this.onClose,
    required this.onVerDetalle,
  });

  Future<void> _abrirGoogleMaps() async {
    final ub = local['ubicacion'] as Map<String, dynamic>?;
    if (ub == null) return;
    final lat = (ub['lat'] as num).toDouble();
    final lng = (ub['lng'] as num).toDouble();
    final native = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final web = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(native)) {
      await launchUrl(native);
    } else {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalle =
        local['detallePromocion'] as Map<String, dynamic>? ?? {};
    final placeName =
        detalle['placeName']?.toString() ?? local['nombre']?.toString() ?? 'Local';
    final title = detalle['title']?.toString() ?? '';
    final logoUrl = detalle['logoUrl']?.toString() ?? '';
    final address = detalle['address']?.toString() ?? '';

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Logo
            Container(
              width: 54,
              height: 54,
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
                  : const Icon(Icons.storefront, color: Palette.kMuted, size: 26),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                      style:
                          const TextStyle(color: Palette.kMuted, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: Palette.kMuted),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                                color: Palette.kMuted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Botón cómo llegar
            if (local['ubicacion'] != null)
              IconButton(
                onPressed: _abrirGoogleMaps,
                tooltip: 'Cómo llegar',
                icon: const Icon(Icons.directions, color: Colors.blue, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 6),
            // Botón ver detalle
            ElevatedButton(
              onPressed: onVerDetalle,
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.kAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Ver',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            // Cerrar
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18, color: Palette.kMuted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Painter punta del pin ──────────────────────────────────────────────────

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}
