import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../ui/palette.dart';
import '../../models/promotion_models.dart';
import '../../widgets/info_tiny_light.dart';

/// ==========================
/// LISTA DE CUPONERAS (sin QR ni historial, sin buscador)
/// ==========================
class CuponerasScreenLight extends StatelessWidget {
  final List<Cuponera> cuponeras;
  const CuponerasScreenLight({super.key, required this.cuponeras});

  @override
  Widget build(BuildContext context) {
    if (cuponeras.isEmpty) {
      return const Center(
        child: Text('No tienes cuponeras activas', style: TextStyle(color: Palette.kMuted)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: cuponeras.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _CuponeraListCard(
        c: cuponeras[i],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CuponeraDetailScreenLight(
                cuponera: cuponeras[i],
                // TODO: reemplaza con tu refresco real (llamando a backend)
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 600));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ==========================
/// CARD DE LISTA (compacta, sin QR ni historial)
/// ==========================
class _CuponeraListCard extends StatelessWidget {
  final Cuponera c;
  final VoidCallback onTap;
  const _CuponeraListCard({required this.c, required this.onTap});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final border = Palette.kBorder;
    final muted = Palette.kMuted;
    final title = Palette.kTitle;

    // Último uso (si hay)
    String? lastUse;
    if (c.scans.isNotEmpty) {
      final sorted = [...c.scans]..sort((a, b) => b.fecha.compareTo(a.fecha));
      lastUse = _fmt(sorted.first.fecha);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con nombre y código (sin overflow)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    c.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: title, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Palette.kField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(c.codigo, style: TextStyle(color: muted, fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            // Descripción (1-2 líneas)
            Text(
              c.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted),
            ),

            const SizedBox(height: 10),
            // Meta info resumida
            Row(
              children: [
                Icon(Icons.confirmation_num_outlined, color: muted, size: 16),
                const SizedBox(width: 4),
                Text('${c.scans.length} ${c.scans.length == 1 ? "escaneo" : "escaneos"}',
                    style: TextStyle(color: muted)),
                const SizedBox(width: 12),
                if (lastUse != null) ...[
                  Icon(Icons.history, color: muted, size: 16),
                  const SizedBox(width: 4),
                  Text('Último uso: $lastUse', style: TextStyle(color: muted)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ==========================
/// DETALLE DE CUPONERA
/// - QR
/// - Info
/// - Historial con búsqueda por local
/// - Pull-to-refresh (+ botón en AppBar)
/// ==========================
class CuponeraDetailScreenLight extends StatefulWidget {
  final Cuponera cuponera;
  final Future<void> Function()? onRefresh; // opcional: refresco real desde backend

  const CuponeraDetailScreenLight({
    super.key,
    required this.cuponera,
    this.onRefresh,
  });

  @override
  State<CuponeraDetailScreenLight> createState() => _CuponeraDetailScreenLightState();
}

class _CuponeraDetailScreenLightState extends State<CuponeraDetailScreenLight> {
  String q = '';

  String _fmtFull(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  Future<void> _handleRefresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    } else {
      await Future.delayed(const Duration(milliseconds: 600));
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final border = Palette.kBorder;
    final muted = Palette.kMuted;
    final title = Palette.kTitle;

    // ordenar desc por fecha
    final scansSorted = [...widget.cuponera.scans]..sort((a, b) => b.fecha.compareTo(a.fecha));
    final query = q.trim().toLowerCase();
    final scans = query.isEmpty
        ? scansSorted
        : scansSorted.where((s) => s.local.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cuponera.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Palette.kSurface,
        foregroundColor: Palette.kTitle,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: Palette.kBg,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            // Card principal con QR e info
            Container(
              decoration: BoxDecoration(
                color: Palette.kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header nombre + código
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.cuponera.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: title, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Palette.kField,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Text(widget.cuponera.codigo, style: TextStyle(color: muted, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(widget.cuponera.descripcion, style: TextStyle(color: muted)),
                  const SizedBox(height: 12),

                  // QR centrado
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: widget.cuponera.qrData,
                        version: QrVersions.auto,
                        size: 180,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Info
                  InfoTinyLight(icon: Icons.event_available, label: 'Emitida: ${_fmtFull(widget.cuponera.emitidaEl)}'),
                  const SizedBox(height: 6),
                  InfoTinyLight(
                    icon: Icons.event_busy,
                    label: widget.cuponera.expiraEl != null
                        ? 'Expira: ${_fmtFull(widget.cuponera.expiraEl!)}'
                        : 'Sin fecha de expiración',
                  ),
                  const SizedBox(height: 6),
                  InfoTinyLight(icon: Icons.key, label: 'QR data: ${widget.cuponera.qrData}'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Historial de escaneos + búsqueda
            Container(
              decoration: BoxDecoration(
                color: Palette.kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))],
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.history, color: muted, size: 18),
                    const SizedBox(width: 6),
                    Text('Historial de escaneos', style: TextStyle(color: title, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    // contador
                    if (scansSorted.isNotEmpty)
                      Text('${scans.length}/${scansSorted.length}', style: TextStyle(color: muted)),
                  ]),
                  const SizedBox(height: 8),

                  // Búsqueda (por nombre de local)
                  TextField(
                    onChanged: (v) => setState(() => q = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar por local… ',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: Palette.kField,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Palette.kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Palette.kAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  if (scans.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No hay coincidencias', style: TextStyle(color: muted)),
                    )
                  else
                    ...scans.map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.store_mall_directory_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.local, style: TextStyle(color: title, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.ciudad} • ${_fmtFull(s.fecha)} • Usuario: ${s.usuario}',
                                    style: TextStyle(color: muted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
