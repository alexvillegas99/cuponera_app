import 'package:enjoy/mappers/cuponera.dart';
import 'package:enjoy/screens/clientes/detalle_cupon.dart';
import 'package:flutter/material.dart';
import '../../ui/palette.dart';

/// ==========================
/// LISTA DE CUPONERAS (look tipo "ticket")
/// ==========================
class CuponerasScreenLight extends StatelessWidget {
  final List<Cuponera> cuponeras;
  final Future<void> Function()? onAddCuponera; // callback para escanear / agregar

  const CuponerasScreenLight({
    super.key,
    required this.cuponeras,
    this.onAddCuponera,
  });

  // FAB siempre visible, abajo-derecha
  Widget _buildFab(BuildContext context) {
    // si no te pasan callback, igual mostramos el botón pero deshabilitado
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          // si tu bottom bar tapa el botón, sube este valor (p.ej. 72)
          padding: const EdgeInsets.only(right: 16, bottom: 16),
          child: FloatingActionButton.extended(
            onPressed: onAddCuponera,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Agregar cuponera'),
            backgroundColor:
                onAddCuponera == null ? Colors.grey : Palette.kAccent,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cuponeras.isEmpty) {
      return Stack(
        children: [
          const Center(
            child: Text(
              'No tienes cuponeras activas',
              style: TextStyle(color: Palette.kMuted),
            ),
          ),
          _buildFab(context),
        ],
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: cuponeras.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _CuponeraTicketCard(
            c: cuponeras[i],
            onTap: () {
              Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => CuponDetalleScreen(cuponId: cuponeras[i].id /* o .codigo */),
  ),
);

            },
          ),
        ),
        _buildFab(context),
      ],
    );
  }
}

/// ==========================
/// CARD estilo ticket
/// ==========================
class _CuponeraTicketCard extends StatelessWidget {
  final Cuponera c;
  final VoidCallback onTap;
  const _CuponeraTicketCard({required this.c, required this.onTap});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  int? _diasRestantes(DateTime? expira) {
    if (expira == null) return null;
    final now = DateTime.now();
    if (expira.isBefore(now)) return 0;
    final base = DateTime(now.year, now.month, now.day);
    return expira.difference(base).inDays;
  }

  double? _lifeProgress(DateTime emitida, DateTime? expira) {
    if (expira == null) return null;
    final total = expira.difference(emitida).inSeconds;
    if (total <= 0) return 1;
    final elapsed = DateTime.now().difference(emitida).inSeconds;
    return (elapsed / total).clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final border = Palette.kBorder;
    final muted = Palette.kMuted;
    final title = Palette.kTitle;

    final dias = _diasRestantes(c.expiraEl);
    final vencida = c.expiraEl != null && c.expiraEl!.isBefore(DateTime.now());
    final porExpirar = !vencida && dias != null && dias <= 7;

    final statusLabel = vencida ? 'Vencida' : (porExpirar ? 'Por expirar' : 'Activa');
    final statusColor = vencida
        ? Colors.redAccent
        : (porExpirar ? Colors.amber.shade700 : Colors.green);

    final String? lastUse = c.scans.isNotEmpty
        ? _fmt((List.of(c.scans)..sort((a, b) => b.fecha.compareTo(a.fecha))).first.fecha)
        : (c.lastScanAt != null ? _fmt(c.lastScanAt!) : null);

    final count = c.scans.isNotEmpty ? c.scans.length : c.totalEscaneos;
    final progress = _lifeProgress(c.emitidaEl, c.expiraEl);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Banda superior (gradiente)
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Palette.kAccent.withOpacity(0.95),
                    Palette.kAccent.withOpacity(0.75),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_activity_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _StatusChip(label: statusLabel, color: statusColor),
                ],
              ),
            ),

            // “Mordidas” + divisor punteado
            SizedBox(
              height: 20,
              child: Stack(
                children: [
                  const Positioned.fill(child: _DashedDivider()),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Palette.kBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: border, width: 1),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Palette.kBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: border, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.descripcion.trim().isNotEmpty) ...[
                    Text(
                      c.descripcion,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 10),
                  ],

                  Row(
                    children: [
                      Icon(Icons.confirmation_num_outlined, color: muted, size: 18),
                      const SizedBox(width: 6),
                      Text('$count ${count == 1 ? "escaneo" : "escaneos"}',
                          style: TextStyle(color: muted)),
                      const SizedBox(width: 14),
                      if (lastUse != null) ...[
                        Icon(Icons.history, color: muted, size: 18),
                        const SizedBox(width: 6),
                        Text('Último uso: $lastUse', style: TextStyle(color: muted)),
                      ],
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, color: muted),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Icon(Icons.event_available, color: muted, size: 18),
                      const SizedBox(width: 6),
                      Text('Emitida: ${_fmt(c.emitidaEl)}', style: TextStyle(color: muted)),
                      const SizedBox(width: 12),
                      Icon(Icons.event_busy, color: muted, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        c.expiraEl != null
                            ? 'Expira: ${_fmt(c.expiraEl!)}'
                            : 'Sin fecha de expiración',
                        style: TextStyle(color: muted),
                      ),
                    ],
                  ),

                  if (progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Palette.kField,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          vencida
                              ? Colors.redAccent
                              : (porExpirar ? Colors.amber : Palette.kAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Inicio', style: TextStyle(color: Palette.kMuted, fontSize: 12)),
                        Text(
                          dias == null ? 'Sin límite' : (vencida ? 'Vencida' : 'Restan $dias días'),
                          style: TextStyle(color: Palette.kMuted, fontSize: 12),
                        ),
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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: Palette.kBorder),
      child: const SizedBox.expand(),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  _DashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    const dashWidth = 6.0, dashSpace = 6.0;
    double startX = 28;
    final endX = size.width - 28;
    final y = size.height / 2;
    while (startX < endX) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
