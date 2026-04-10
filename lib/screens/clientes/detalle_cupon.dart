import 'package:enjoy/screens/clientes/comercio_detalle_mini_screen.dart';
import 'package:enjoy/screens/clientes/mapa_version_screen.dart';
import 'package:enjoy/services/versiones_service.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/mappers/detalle_cupon.dart';

class CuponDetalleScreen extends StatefulWidget {
  final String cuponId;
  const CuponDetalleScreen({super.key, required this.cuponId});

  @override
  State<CuponDetalleScreen> createState() => _CuponDetalleScreenState();
}

class _CuponDetalleScreenState extends State<CuponDetalleScreen>
    with SingleTickerProviderStateMixin {
  final _svc = CuponesService();
  DetalleCupon? _data;
  bool _loading = true;
  String? _error;
  late TabController _tab;
  String _qPend = '';
  String _qScan = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _svc.obtenerDetallePorCupon(widget.cuponId);
      if (!mounted) return;
      setState(() => _data = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Future<void> _verMapa() async {
    final versionId = _data?.version.id;
    if (versionId == null || versionId.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Palette.kAccent)),
    );
    try {
      final locales = await VersionesService.listarLocales(versionId);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => MapaVersionScreen(
          versionNombre: _data!.version.nombre,
          locales: locales,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el mapa.')),
      );
    }
  }

  // ─────────────────────────── BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kSurface,
        foregroundColor: Palette.kTitle,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _data?.version.nombre ?? 'Detalle cuponera',
          style: const TextStyle(
            color: Palette.kTitle,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Palette.kMuted),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Palette.kSurface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 1, color: Palette.kBorder),
                TabBar(
                  controller: _tab,
                  labelColor: Palette.kAccent,
                  unselectedLabelColor: Palette.kMuted,
                  indicatorColor: Palette.kAccent,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Por escanear'),
                    Tab(text: 'Escaneados'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Palette.kAccent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Palette.kMuted)),
            ],
          ),
        ),
      );
    }
    if (_data == null) {
      return const Center(child: Text('Sin datos'));
    }

    return RefreshIndicator(
      color: Palette.kAccent,
      onRefresh: _load,
      child: TabBarView(
        controller: _tab,
        children: [
          _buildTabContent(isPendiente: true),
          _buildTabContent(isPendiente: false),
        ],
      ),
    );
  }

  // ─────────────────────────── TAB CONTENT
  Widget _buildTabContent({required bool isPendiente}) {
    final d = _data!;

    final pendientes = d.lugaresSinScannear.where((x) {
      final s = '${x.nombre} ${x.email} ${x.title} ${x.scheduleLabel}'.toLowerCase();
      return s.contains(_qPend.trim().toLowerCase());
    }).toList();

    final escaneados = d.lugaresScaneados.where((x) {
      final s = '${x.nombre} ${x.email} ${x.title} ${x.scheduleLabel}'.toLowerCase();
      return s.contains(_qScan.trim().toLowerCase());
    }).toList();

    final list = isPendiente ? pendientes : escaneados;
    final query = isPendiente ? _qPend : _qScan;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Info card (cuponera) ──
        _buildInfoCard(d),
        const SizedBox(height: 12),

        // ── Stats ──
        _buildStatsRow(d),
        const SizedBox(height: 12),

        // ── Mapa ──
        if (d.version.id != null) ...[
          GestureDetector(
            onTap: _verMapa,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Palette.kPrimary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Palette.kPrimary.withOpacity(0.15)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded, size: 17, color: Palette.kPrimary),
                  SizedBox(width: 7),
                  Text(
                    'Ver locales en el mapa',
                    style: TextStyle(color: Palette.kPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Buscador ──
        _buildSearchBox(
          hint: isPendiente ? 'Buscar local por escanear…' : 'Buscar local escaneado…',
          onChanged: (v) => setState(() => isPendiente ? _qPend = v : _qScan = v),
        ),
        const SizedBox(height: 10),

        // ── Lista vacía ──
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: Palette.kField, borderRadius: BorderRadius.circular(14)),
                  child: Icon(
                    isPendiente ? Icons.store_mall_directory_outlined : Icons.check_circle_outline_rounded,
                    color: Palette.kMuted, size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  query.isNotEmpty
                      ? 'Sin resultados para "$query"'
                      : isPendiente
                          ? '¡Ya escaneaste todos los locales!'
                          : 'Aún no has escaneado ningún local',
                  style: const TextStyle(color: Palette.kMuted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

        // ── Cards de locales ──
        if (isPendiente)
          ...pendientes.map((l) => _LocalTile(
            nombre: l.nombre,
            title: l.title,
            logoUrl: l.logoUrl,
            rating: l.rating,
            scheduleLabel: l.scheduleLabel,
            ciudades: l.ciudades,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ComercioDetalleMiniScreen(usuarioId: l.usuarioId),
            )),
          ))
        else
          ...escaneados.map((l) => _LocalTile(
            nombre: l.nombre,
            title: l.title,
            logoUrl: l.logoUrl,
            rating: l.rating,
            scheduleLabel: l.scheduleLabel,
            ciudades: l.ciudades,
            scanCount: l.count,
            lastScan: l.lastScan,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ComercioDetalleMiniScreen(usuarioId: l.usuarioId),
            )),
          )),
      ],
    );
  }

  // ─────────────────────────── INFO CARD
  Widget _buildInfoCard(DetalleCupon d) {
    final c = d.cupon;
    final v = d.version;

    Color estadoColor;
    switch (c.estado.toLowerCase()) {
      case 'activo':  estadoColor = const Color(0xFF27AE60); break;
      case 'vencido': estadoColor = Colors.redAccent; break;
      default:        estadoColor = Colors.amber.shade700;
    }

    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header gradiente
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Palette.kAccent, Palette.kAccentLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_activity_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      if (c.secuencial != null) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Nº ${c.secuencial.toString().padLeft(3, '0')}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: estadoColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(c.estado, style: TextStyle(color: estadoColor, fontWeight: FontWeight.w700, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body con QR + info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // QR
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: QrImageView(data: widget.cuponId, version: QrVersions.auto, size: 110),
                ),
                const SizedBox(width: 14),

                // Info rows
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(icon: Icons.qr_code_scanner_rounded, iconColor: Palette.kAccent, label: 'Escaneos', value: '${c.numeroDeEscaneos}'),
                      if (c.fechaActivacion != null) ...[
                        const SizedBox(height: 8),
                        _infoRow(icon: Icons.event_available_rounded, iconColor: const Color(0xFF27AE60), label: 'Activación', value: _fmt(c.fechaActivacion!)),
                      ],
                      if (c.fechaVencimiento != null) ...[
                        const SizedBox(height: 8),
                        _infoRow(icon: Icons.event_busy_rounded, iconColor: Colors.redAccent, label: 'Vence', value: _fmt(c.fechaVencimiento!)),
                      ],
                      if (c.ultimoScaneo != null) ...[
                        const SizedBox(height: 8),
                        _infoRow(icon: Icons.history_rounded, iconColor: Palette.kMuted, label: 'Último uso', value: _fmt(c.ultimoScaneo!)),
                      ],
                      if (v.ciudadesDisponibles.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 5, runSpacing: 4,
                          children: v.ciudadesDisponibles.map((ci) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Palette.kAccent.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(ci, style: const TextStyle(color: Palette.kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Descripción
          if ((v.descripcion ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.kField,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Palette.kBorder),
                ),
                child: Text(v.descripcion!, style: const TextStyle(color: Palette.kMuted, fontSize: 13, height: 1.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow({required IconData icon, required Color iconColor, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Palette.kMuted, fontSize: 10, fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── STATS ROW
  Widget _buildStatsRow(DetalleCupon d) {
    final esc = d.totalLugaresScaneados;
    final total = d.candidatosTotal;
    final pct = total > 0 ? (esc / total * 100).round() : 0;
    final pctColor = pct >= 70 ? const Color(0xFF27AE60) : (pct >= 30 ? Colors.amber.shade700 : Palette.kMuted);

    return Row(
      children: [
        _statCard(icon: Icons.store_rounded, iconColor: Palette.kPrimary, value: '$esc / $total', label: 'Locales'),
        const SizedBox(width: 10),
        _statCard(icon: Icons.qr_code_scanner_rounded, iconColor: Palette.kAccent, value: '${d.totalEscaneos}', label: 'Escaneos'),
        const SizedBox(width: 10),
        _statCard(icon: Icons.percent_rounded, iconColor: pctColor, value: '$pct%', label: 'Completado'),
      ],
    );
  }

  Widget _statCard({required IconData icon, required Color iconColor, required String value, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w800, fontSize: 15)),
            Text(label, style: const TextStyle(color: Palette.kMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── SEARCH BOX
  Widget _buildSearchBox({required String hint, required ValueChanged<String> onChanged}) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: Palette.kMuted, size: 20),
        isDense: true,
        filled: true,
        fillColor: Palette.kSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent, width: 1.4)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Tile de local
// ══════════════════════════════════════════════════════════════════
class _LocalTile extends StatelessWidget {
  final String nombre;
  final String? title;
  final String? logoUrl;
  final double? rating;
  final String? scheduleLabel;
  final List<String> ciudades;
  final int? scanCount;
  final DateTime? lastScan;
  final VoidCallback? onTap;

  const _LocalTile({
    required this.nombre,
    required this.ciudades,
    this.title,
    this.logoUrl,
    this.rating,
    this.scheduleLabel,
    this.scanCount,
    this.lastScan,
    this.onTap,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Palette.kField,
                shape: BoxShape.circle,
                border: Border.all(color: Palette.kBorder),
              ),
              child: ClipOval(
                child: (logoUrl != null && logoUrl!.isNotEmpty)
                    ? Image.network(logoUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.store_mall_directory_outlined, color: Palette.kMuted, size: 24))
                    : const Icon(Icons.store_mall_directory_outlined, color: Palette.kMuted, size: 24),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + chevron
                  Row(
                    children: [
                      Expanded(
                        child: Text(nombre, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Palette.kMuted, size: 20),
                    ],
                  ),

                  if ((title ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
                  ],

                  const SizedBox(height: 5),

                  // Rating + horario
                  if ((rating != null && rating! > 0) || (scheduleLabel ?? '').isNotEmpty)
                    Row(
                      children: [
                        if (rating != null && rating! > 0) ...[
                          _Stars(rating: rating),
                          const SizedBox(width: 6),
                        ],
                        if ((scheduleLabel ?? '').isNotEmpty)
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: Palette.kMuted),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(scheduleLabel!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Palette.kMuted, fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                  // Ciudades
                  if (ciudades.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5, runSpacing: 3,
                      children: ciudades.map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Palette.kAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(c, style: const TextStyle(color: Palette.kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ],

                  // Badge escaneado
                  if (scanCount != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF27AE60)),
                              const SizedBox(width: 4),
                              Text(
                                '$scanCount ${scanCount == 1 ? "escaneo" : "escaneos"}',
                                style: const TextStyle(color: Color(0xFF27AE60), fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        if (lastScan != null) ...[
                          const SizedBox(width: 6),
                          Text('Último: ${_fmt(lastScan!)}',
                              style: const TextStyle(color: Palette.kMuted, fontSize: 11)),
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
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Estrellas
// ══════════════════════════════════════════════════════════════════
class _Stars extends StatelessWidget {
  final double? rating;
  const _Stars({this.rating});

  @override
  Widget build(BuildContext context) {
    final r = (rating ?? 0.0).clamp(0.0, 5.0);
    final full = r.floor();
    final half = (r - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return const Icon(Icons.star_rounded, size: 14, color: Colors.amber);
        if (i == full && half) return const Icon(Icons.star_half_rounded, size: 14, color: Colors.amber);
        return const Icon(Icons.star_border_rounded, size: 14, color: Colors.amber);
      }),
    );
  }
}
