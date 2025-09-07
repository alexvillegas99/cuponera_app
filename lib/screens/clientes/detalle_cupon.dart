import 'package:enjoy/screens/clientes/comercio_detalle_mini_screen.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/mappers/detalle_cupon.dart';

class CuponDetalleScreen extends StatefulWidget {
  final String cuponId; // <- SOLO el id/code/uuid del cupón

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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

  String _fmtFull(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final muted = Palette.kMuted;
    final title = Palette.kTitle;
    final border = Palette.kBorder;

    return Scaffold(
      appBar: AppBar(
        title: Text(_data?.version.nombre ?? 'Detalle cuponera'),
         backgroundColor: Palette.kAccent,
        foregroundColor: Palette.kBorder,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white ,
          unselectedLabelColor: Colors.white54,
           indicatorColor: Colors.red, 
          tabs: const [
            Tab(text: 'Por escanear'),
            Tab(text: 'Escaneados'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: Palette.kBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : _data == null
          ? const Center(child: Text('Sin datos'))
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tab,
                children: [
                  // TAB 1: PENDIENTES
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      _HeaderCupon(
                        cuponId: widget.cuponId,
                        versionNombre: _data!.version.nombre,
                        ciudades: _data!.version.ciudadesDisponibles,
                        cupon: _data!.cupon,
                      ),
                      const SizedBox(height: 14),
                      _SearchBox(
                        hint: 'Buscar local por escanear…',
                        onChanged: (v) => setState(() => _qPend = v),
                      ),
                      const SizedBox(height: 8),
                      ..._buildPendientesList(
                        _data!,
                        _qPend,
                        title,
                        muted,
                        border,
                      ),
                    ],
                  ),

                  // TAB 2: ESCANEADOS
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      _HeaderCupon(
                        cuponId: widget.cuponId,
                        versionNombre: _data!.version.nombre,
                        ciudades: _data!.version.ciudadesDisponibles,
                        cupon: _data!.cupon,
                      ),
                      const SizedBox(height: 14),
                      _SearchBox(
                        hint: 'Buscar local escaneado…',
                        onChanged: (v) => setState(() => _qScan = v),
                      ),
                      const SizedBox(height: 8),
                      ..._buildScaneadosList(
                        _data!,
                        _qScan,
                        title,
                        muted,
                        border,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildPendientesList(
    DetalleCupon d,
    String q,
    Color title,
    Color muted,
    Color border,
  ) {
    final list = d.lugaresSinScannear.where((x) {
      final s = '$x ${x.nombre} ${x.email} ${x.title} ${x.scheduleLabel}'
          .toLowerCase();
      return s.contains(q.trim().toLowerCase());
    }).toList();

    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text('No hay coincidencias', style: TextStyle(color: muted)),
        ),
      ];
    }

    return list
        .map(
          (l) => _LocalCard(
            nombre: l.nombre,
            email: l.email,
            ciudades: l.ciudades,
            title: l.title,
            logoUrl: l.logoUrl,
            rating: l.rating,
            scheduleLabel: l.scheduleLabel,
            border: border,
            titleColor: title,
            muted: muted,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ComercioDetalleMiniScreen(
                    usuarioId: l.usuarioId,
                  ), // <--- usa el id real del usuario
                ),
              );
            },
          ),
        )
        .toList();
  }

  List<Widget> _buildScaneadosList(
    DetalleCupon d,
    String q,
    Color title,
    Color muted,
    Color border,
  ) {
    final list = d.lugaresScaneados.where((x) {
      final s = '${x.nombre} ${x.email} ${x.title} ${x.scheduleLabel}'
          .toLowerCase();
      return s.contains(q.trim().toLowerCase());
    }).toList();

    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text('No hay coincidencias', style: TextStyle(color: muted)),
        ),
      ];
    }

    return list
        .map(
          (l) => _LocalCard(
            nombre: l.nombre,
            email: l.email,
            ciudades: l.ciudades,
            title: l.title,
            logoUrl: l.logoUrl,
            rating: l.rating,
            scheduleLabel: l.scheduleLabel,
            count: l.count,
            lastScan: l.lastScan,
            border: border,
            titleColor: title,
            muted: muted,
             onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ComercioDetalleMiniScreen(
                    usuarioId: l.usuarioId,
                  ), // <--- usa el id real del usuario
                ),
              );
            },
          ),
        )
        .toList();
  }
}

class _HeaderCupon extends StatelessWidget {
  final String cuponId; // para QR
  final String versionNombre;
  final List<String> ciudades;
  final CuponMeta cupon;

  const _HeaderCupon({
    required this.cuponId,
    required this.versionNombre,
    required this.ciudades,
    required this.cupon,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final border = Palette.kBorder;
    final muted = Palette.kMuted;
    final title = Palette.kTitle;

    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  versionNombre,
                  style: TextStyle(
                    color: title,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Palette.kField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Text(
                  cupon.estado,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // QR desde el cuponId (uuid/id)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                padding: const EdgeInsets.all(10),
                child: QrImageView(
                  data: cuponId,
                  version: QrVersions.auto,
                  size: 110,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: -6,
                      children: ciudades
                          .map(
                            (c) => Chip(
                              label: Text(
                                c,
                                style: const TextStyle(fontSize: 12),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(color: border),
                              backgroundColor: Palette.kField,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Escaneos: ${cupon.numeroDeEscaneos}',
                      style: TextStyle(
                        color: title,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Activación: ${cupon.fechaActivacion != null ? _fmt(cupon.fechaActivacion!) : '—'}',
                      style: TextStyle(color: muted),
                    ),
                    Text(
                      'Vence: ${cupon.fechaVencimiento != null ? _fmt(cupon.fechaVencimiento!) : '—'}',
                      style: TextStyle(color: muted),
                    ),
                    Text(
                      'Último uso: ${cupon.ultimoScaneo != null ? _fmt(cupon.ultimoScaneo!) : '—'}',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchBox({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: Palette.kField,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.kAccent),
        ),
      ),
    );
  }
}

class _LocalCard extends StatelessWidget {
  final String nombre;
  final String email;
  final List<String> ciudades;
  final String? title;
  final String? logoUrl;
  final double? rating;
  final String? scheduleLabel;
  final int? count; // solo para escaneados
  final DateTime? lastScan; // solo para escaneados

  final Color border;
  final Color titleColor;
  final Color muted;

  // 👇 NUEVO: callback para navegar
  final VoidCallback? onTap;

  const _LocalCard({
    required this.nombre,
    required this.email,
    required this.ciudades,
    required this.title,
    required this.logoUrl,
    required this.rating,
    required this.scheduleLabel,
    this.count,
    this.lastScan,
    required this.border,
    required this.titleColor,
    required this.muted,
    this.onTap, // 👈 NUEVO
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, // 👈 hace el card “tappable”
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Palette.kField,
              backgroundImage: (logoUrl != null && logoUrl!.isNotEmpty)
                  ? NetworkImage(logoUrl!)
                  : null,
              child: (logoUrl == null || logoUrl!.isEmpty)
                  ? const Icon(Icons.store_mall_directory_outlined)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ), // hint visual de navegación
                    ],
                  ),
                  if (title != null && title!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: ciudades
                        .map(
                          (c) => Chip(
                            label: Text(
                              c,
                              style: const TextStyle(fontSize: 11),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: border),
                            backgroundColor: Palette.kField,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                 /*  Row(
                    children: [
                      _Stars(rating: rating),
                      const SizedBox(width: 8),
                      if (scheduleLabel != null && scheduleLabel!.isNotEmpty)
                        Flexible(
                          child: Text(
                            scheduleLabel!,
                            style: TextStyle(color: muted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ), */
                /*   if (count != null || lastScan != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (count != null) ...[
                          const Icon(
                            Icons.qr_code_2,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Escaneos: $count',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (lastScan != null) ...[
                          const Icon(
                            Icons.history,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Último: '
                            '${lastScan!.day.toString().padLeft(2, '0')}/'
                            '${lastScan!.month.toString().padLeft(2, '0')}/'
                            '${lastScan!.year} '
                            '${lastScan!.hour.toString().padLeft(2, '0')}:'
                            '${lastScan!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
               */  ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final double? rating;
  const _Stars({this.rating});

  @override
  Widget build(BuildContext context) {
    final r = (rating ?? 0).clamp(0, 5).toDouble();
    final full = r.floor();
    final half = (r - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full)
          return const Icon(Icons.star, size: 16, color: Colors.amber);
        if (i == full && half)
          return const Icon(Icons.star_half, size: 16, color: Colors.amber);
        return const Icon(Icons.star_border, size: 16, color: Colors.amber);
      }),
    );
  }
}
