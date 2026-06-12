import 'package:enjoy/screens/clientes/comercio_detalle_mini_screen.dart';
import 'package:enjoy/screens/clientes/mapa_version_screen.dart';
import 'package:enjoy/services/versiones_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
    _tab.addListener(() => setState(() {}));
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
      builder: (_) =>
          Center(child: CircularProgressIndicator(color: context.ec.orange)),
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
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: EnjoyAppBar(
        title: _data?.version.nombre ?? 'Detalle membresía',
        actions: [
          GlassIconButton(icon: Icons.refresh_rounded, onTap: _load),
        ],
      ),
      body: Column(
        children: [
          _buildTabs(ec),
          Expanded(child: _buildBody(ec)),
        ],
      ),
    );
  }

  Widget _buildTabs(EnjoyColors ec) {
    final tabs = ['Por escanear', 'Escaneados'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: ec.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ec.stroke),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = _tab.index == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab.animateTo(i)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: active ? ec.accentGradient : null,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    tabs[i],
                    style: EnjoyTheme.heading(
                      size: 13,
                      weight: FontWeight.w600,
                      color: active ? ec.onAccent : ec.textSoft,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBody(EnjoyColors ec) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: ec.orange));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBox(Icons.error_outline_rounded,
                  size: 56, iconSize: 28, color: ec.red),
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: EnjoyTheme.body(color: ec.textMute)),
            ],
          ),
        ),
      );
    }
    if (_data == null) {
      return Center(
          child: Text('Sin datos', style: EnjoyTheme.body(color: ec.textMute)));
    }

    return RefreshIndicator(
      color: ec.orange,
      backgroundColor: ec.surfaceMid,
      onRefresh: _load,
      child: TabBarView(
        controller: _tab,
        children: [
          _buildTabContent(ec, isPendiente: true),
          _buildTabContent(ec, isPendiente: false),
        ],
      ),
    );
  }

  // ─────────────────────────── TAB CONTENT
  Widget _buildTabContent(EnjoyColors ec, {required bool isPendiente}) {
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Info card (cuponera) ──
        _buildInfoCard(ec, d),
        const SizedBox(height: 12),

        // ── Stats ──
        _buildStatsRow(ec, d),
        const SizedBox(height: 12),

        // ── Mapa ──
        if (d.version.id != null) ...[
          EnjoyButton(
            label: 'Ver locales en el mapa',
            icon: Icons.map_rounded,
            variant: EnjoyButtonVariant.blueGlass,
            dense: true,
            onPressed: _verMapa,
          ),
          const SizedBox(height: 12),
        ],

        // ── Buscador ──
        TextField(
          onChanged: (v) =>
              setState(() => isPendiente ? _qPend = v : _qScan = v),
          style: EnjoyTheme.body(size: 14, color: ec.text),
          decoration: InputDecoration(
            hintText: isPendiente
                ? 'Buscar local por escanear…'
                : 'Buscar local escaneado…',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child:
                  Icon(Icons.search_rounded, color: ec.orangeSoft, size: 20),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
        const SizedBox(height: 12),

        // ── Lista vacía ──
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                IconBox(
                  isPendiente
                      ? Icons.store_mall_directory_outlined
                      : Icons.check_circle_outline_rounded,
                  size: 52,
                  iconSize: 24,
                  color: ec.textMute,
                ),
                const SizedBox(height: 10),
                Text(
                  query.isNotEmpty
                      ? 'Sin resultados para "$query"'
                      : isPendiente
                          ? '¡Ya escaneaste todos los locales!'
                          : 'Aún no has escaneado ningún local',
                  style: EnjoyTheme.body(size: 14, color: ec.textMute),
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
  Widget _buildInfoCard(EnjoyColors ec, DetalleCupon d) {
    final c = d.cupon;
    final v = d.version;

    Color estadoColor;
    switch (c.estado.toLowerCase()) {
      case 'activo':  estadoColor = ec.green; break;
      case 'vencido': estadoColor = ec.red; break;
      default:        estadoColor = ec.yellow;
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header gradiente
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              gradient: ec.accentGradient,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: ec.onAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.local_activity_rounded,
                      color: ec.onAccent, size: 20),
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
                        style: EnjoyTheme.heading(
                            size: 16,
                            weight: FontWeight.w800,
                            color: ec.onAccent),
                      ),
                      if (c.secuencial != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ec.onAccent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Nº ${c.secuencial.toString().padLeft(3, '0')}',
                            style: EnjoyTheme.body(
                                size: 11,
                                weight: FontWeight.w700,
                                color: ec.onAccent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ec.onAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: estadoColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(c.estado,
                          style: EnjoyTheme.body(
                              size: 11,
                              weight: FontWeight.w700,
                              color: ec.onAccent)),
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
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: QrImageView(
                      data: widget.cuponId,
                      version: QrVersions.auto,
                      size: 110),
                ),
                const SizedBox(width: 14),

                // Info rows
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(ec,
                          icon: Icons.qr_code_scanner_rounded,
                          iconColor: ec.orange,
                          label: 'Escaneos',
                          value: '${c.numeroDeEscaneos}'),
                      if (c.fechaActivacion != null) ...[
                        const SizedBox(height: 8),
                        _infoRow(ec,
                            icon: Icons.event_available_rounded,
                            iconColor: ec.green,
                            label: 'Activación',
                            value: _fmt(c.fechaActivacion!)),
                      ],
                      if (c.fechaVencimiento != null) ...[
                        const SizedBox(height: 8),
                        _infoRow(ec,
                            icon: Icons.event_busy_rounded,
                            iconColor: ec.red,
                            label: 'Vence',
                            value: _fmt(c.fechaVencimiento!)),
                      ],
                      if (c.ultimoScaneo != null) ...[
                        const SizedBox(height: 8),
                        _infoRow(ec,
                            icon: Icons.history_rounded,
                            iconColor: ec.textMute,
                            label: 'Último uso',
                            value: _fmt(c.ultimoScaneo!)),
                      ],
                      if (v.ciudadesDisponibles.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: v.ciudadesDisponibles
                              .map((ci) => Pill(ci,
                                  variant: PillVariant.orange, dense: true))
                              .toList(),
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
                  color: ec.glassStrong,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ec.stroke),
                ),
                child: Text(v.descripcion!,
                    style: EnjoyTheme.body(
                        size: 13, color: ec.textSoft, height: 1.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(EnjoyColors ec,
      {required IconData icon,
      required Color iconColor,
      required String label,
      required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: EnjoyTheme.body(
                      size: 10, weight: FontWeight.w500, color: ec.textMute)),
              Text(value,
                  style: EnjoyTheme.heading(size: 13, color: ec.text)),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── STATS ROW
  Widget _buildStatsRow(EnjoyColors ec, DetalleCupon d) {
    final esc = d.totalLugaresScaneados;
    final total = d.candidatosTotal;
    final pct = total > 0 ? (esc / total * 100).round() : 0;
    final pctColor =
        pct >= 70 ? ec.green : (pct >= 30 ? ec.yellow : ec.textMute);

    return Row(
      children: [
        _statCard(ec,
            icon: Icons.store_rounded,
            iconColor: ec.blue,
            value: '$esc / $total',
            label: 'Locales'),
        const SizedBox(width: 10),
        _statCard(ec,
            icon: Icons.qr_code_scanner_rounded,
            iconColor: ec.orange,
            value: '${d.totalEscaneos}',
            label: 'Escaneos'),
        const SizedBox(width: 10),
        _statCard(ec,
            icon: Icons.percent_rounded,
            iconColor: pctColor,
            value: '$pct%',
            label: 'Completado'),
      ],
    );
  }

  Widget _statCard(EnjoyColors ec,
      {required IconData icon,
      required Color iconColor,
      required String value,
      required String label}) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        radius: 16,
        child: Column(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(value,
                style: EnjoyTheme.heading(
                    size: 15, weight: FontWeight.w800, color: ec.text)),
            Text(label,
                style: EnjoyTheme.body(size: 11, color: ec.textMute)),
          ],
        ),
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
    final ec = context.ec;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      radius: 16,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: ec.iconGlassGradient,
              shape: BoxShape.circle,
              border: Border.all(color: ec.stroke),
            ),
            child: ClipOval(
              child: (logoUrl != null && logoUrl!.isNotEmpty)
                  ? Image.network(logoUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.store_mall_directory_outlined,
                          color: ec.orangeSoft,
                          size: 24))
                  : Icon(Icons.store_mall_directory_outlined,
                      color: ec.orangeSoft, size: 24),
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
                      child: Text(nombre,
                          style:
                              EnjoyTheme.heading(size: 14, color: ec.text)),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: ec.textMute, size: 20),
                  ],
                ),

                if ((title ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EnjoyTheme.body(size: 12, color: ec.textMute)),
                ],

                const SizedBox(height: 6),

                // Rating + horario
                if ((rating != null && rating! > 0) ||
                    (scheduleLabel ?? '').isNotEmpty)
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
                              Icon(Icons.access_time_rounded,
                                  size: 12, color: ec.textMute),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(scheduleLabel!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: EnjoyTheme.body(
                                        size: 11, color: ec.textMute)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                // Ciudades
                if (ciudades.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: ciudades
                        .map((c) => Pill(c,
                            variant: PillVariant.orange, dense: true))
                        .toList(),
                  ),
                ],

                // Badge escaneado
                if (scanCount != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Pill(
                        '$scanCount ${scanCount == 1 ? "escaneo" : "escaneos"}',
                        variant: PillVariant.green,
                        icon: Icons.check_circle_rounded,
                        dense: true,
                      ),
                      if (lastScan != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('Último: ${_fmt(lastScan!)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: EnjoyTheme.body(
                                  size: 11, color: ec.textMute)),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
        if (i < full) {
          return const Icon(Icons.star_rounded, size: 14, color: Colors.amber);
        }
        if (i == full && half) {
          return const Icon(Icons.star_half_rounded,
              size: 14, color: Colors.amber);
        }
        return const Icon(Icons.star_border_rounded,
            size: 14, color: Colors.amber);
      }),
    );
  }
}
