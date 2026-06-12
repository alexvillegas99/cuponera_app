import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import 'comercio_detalle_mini_screen.dart';

/// Fallback: Quito (centro) si no se puede obtener la ubicación.
const LatLng _kQuito = LatLng(-0.22985, -78.52495);

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
  LatLng? _userLocation;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  /// Pide permisos y obtiene la ubicación actual. Centra el mapa en el usuario.
  Future<void> _loadUserLocation({bool recenter = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = loc);
      if (recenter && _mapReady) {
        _mapController.move(loc, 15);
      }
    } catch (_) {
      // Silencioso: el mapa ya tiene un centro de respaldo.
    }
  }

  /// Recentra en el usuario (botón "mi ubicación"). Si aún no se tiene, la pide.
  Future<void> _recenterUser() async {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15);
    } else {
      await _loadUserLocation();
    }
  }

  /// Centro inicial del mapa: usuario > promedio de locales > Quito.
  LatLng get _initialCenter {
    if (_userLocation != null) return _userLocation!;
    final lista = _localesConUbicacion;
    if (lista.isEmpty) return _kQuito;
    return _center;
  }

  List<Map<String, dynamic>> get _localesConUbicacion {
    final result = widget.locales.where((l) {
      final ub = l['ubicacion'];
      return ub != null && ub['lat'] != null && ub['lng'] != null;
    }).toList();
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
    final ec = context.ec;
    final locales = _localesConUbicacion;

    return Scaffold(
      backgroundColor: ec.bgBottom,
      body: locales.isEmpty
          ? _buildEmpty(ec)
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 14.5,
                    // Lienzo según tema mientras cargan los tiles.
                    backgroundColor:
                        ec.isDark ? const Color(0xFF11141B) : const Color(0xFFE8ECF1),
                    onMapReady: () {
                      _mapReady = true;
                      if (_userLocation != null) {
                        _mapController.move(_userLocation!, 15);
                      }
                    },
                    onTap: (_, __) => setState(() => _selectedLocal = null),
                  ),
                  children: [
                    // Tiles CartoDB según tema: dark_all (oscuro) / light_all (claro).
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/${ec.isDark ? "dark_all" : "light_all"}/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.pixelsmart.enjoy',
                      maxZoom: 20,
                    ),
                    // Marcador de la ubicación del usuario.
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 28,
                            height: 28,
                            child: _UserLocationDot(color: ec.blue),
                          ),
                        ],
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
                        // Pines naranjas (mockup); el seleccionado resalta más fuerte.
                        final pinColor =
                            isSelected ? ec.orange : ec.orangeSoft;

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
                                      color: pinColor,
                                      width: isSelected ? 3 : 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: pinColor.withValues(alpha: 0.45),
                                        blurRadius: 12,
                                        spreadRadius: isSelected ? 1 : 0,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: logoUrl.isNotEmpty
                                      ? EnjoyImage(
                                          logoUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: Icon(
                                            Icons.storefront,
                                            color: pinColor,
                                            size: 22,
                                          ),
                                        )
                                      : Icon(
                                          Icons.storefront,
                                          color: pinColor,
                                          size: 22,
                                        ),
                                ),
                                // Punta del pin
                                CustomPaint(
                                  size: const Size(14, 10),
                                  painter: _PinTailPainter(color: pinColor),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // FAB "mi ubicación" (glass) — recentra en el usuario.
                Positioned(
                  right: 16,
                  bottom: _selectedLocal != null ? 190 : 28,
                  child: SafeArea(
                    top: false,
                    child: GlassIconButton(
                      icon: Icons.my_location_rounded,
                      onTap: _recenterUser,
                      accent: true,
                      size: 46,
                    ),
                  ),
                ),

                // Atribución OSM (requerida por los términos de uso)
                Positioned(
                  bottom: _selectedLocal != null ? 140 : 10,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ),
                ),

                // AppBar flotante glass: back + título + contador
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Row(
                      children: [
                        BackChip(
                            onTap: () => Navigator.of(context).maybePop()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.versionNombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EnjoyTheme.heading(size: 18, color: ec.text),
                          ),
                        ),
                        Pill('${locales.length} locales',
                            variant: PillVariant.glass, dense: true),
                      ],
                    ),
                  ),
                ),

                // Tarjeta del local seleccionado
                if (_selectedLocal != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      top: false,
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
                  ),
              ],
            ),
    );
  }

  Widget _buildEmpty(EnjoyColors ec) {
    return EnjoyScaffold(
      appBar: EnjoyAppBar(title: widget.versionNombre),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBox(Icons.location_off_rounded, size: 56, iconSize: 26),
            const SizedBox(height: 14),
            Text(
              'Ningún local tiene ubicación registrada aún.',
              style: EnjoyTheme.body(size: 14, color: ec.textMute),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
    final ec = context.ec;
    final detalle =
        local['detallePromocion'] as Map<String, dynamic>? ?? {};
    final placeName =
        detalle['placeName']?.toString() ?? local['nombre']?.toString() ?? 'Local';
    final title = detalle['title']?.toString() ?? '';
    final logoUrl = detalle['logoUrl']?.toString() ?? '';
    final address = detalle['address']?.toString() ?? '';

    return GlassCard(
      color: ec.isDark ? const Color(0xFF0A1322).withValues(alpha: 0.9) : null,
      borderColor: ec.strokeStrong,
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Logo
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: ec.iconGlassGradient,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: ec.stroke),
                ),
                clipBehavior: Clip.antiAlias,
                child: logoUrl.isNotEmpty
                    ? EnjoyImage(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorWidget: Icon(
                          Icons.storefront,
                          color: ec.orangeSoft,
                          size: 26,
                        ),
                      )
                    : Icon(Icons.storefront, color: ec.orangeSoft, size: 26),
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
                      style: EnjoyTheme.heading(size: 15, color: ec.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: EnjoyTheme.body(size: 13, color: ec.textSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 12, color: ec.textMute),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              address,
                              style: EnjoyTheme.body(
                                  size: 12, color: ec.textMute),
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
              GlassIconButton(
                icon: Icons.close_rounded,
                onTap: onClose,
                size: 32,
              ),
            ],
          ),
          const EnjoyDivider(height: 24),
          Row(
            children: [
              if (local['ubicacion'] != null) ...[
                Expanded(
                  child: EnjoyButton(
                    label: 'Cómo llegar',
                    icon: Icons.directions_rounded,
                    variant: EnjoyButtonVariant.ghost,
                    dense: true,
                    onPressed: _abrirGoogleMaps,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: EnjoyButton(
                  label: 'Ver detalle',
                  dense: true,
                  onPressed: onVerDetalle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Marcador de ubicación del usuario ──────────────────────────────────────

class _UserLocationDot extends StatelessWidget {
  final Color color;
  const _UserLocationDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.55),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
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
