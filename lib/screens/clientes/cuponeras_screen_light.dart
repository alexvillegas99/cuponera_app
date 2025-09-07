// lib/screens/clientes/cuponeras_screen_light.dart
import 'dart:convert';

import 'package:enjoy/mappers/cuponera.dart';
import 'package:enjoy/screens/clientes/detalle_cupon.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/services/auth_service.dart';
import '../../ui/palette.dart';

class CuponerasScreenLight extends StatefulWidget {
  final List<Cuponera> cuponeras;
  final Future<void> Function()? onAddCuponera; // callback externo opcional

  const CuponerasScreenLight({
    super.key,
    required this.cuponeras,
    this.onAddCuponera,
  });

  @override
  State<CuponerasScreenLight> createState() => _CuponerasScreenLightState();
}

class _CuponerasScreenLightState extends State<CuponerasScreenLight> {
  final _cuponSvc = CuponesService();
  final _auth = AuthService();

  late List<Cuponera> _items; // copia local para refrescar
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.cuponeras);
  }

  Future<void> _reloadFromServer() async {
    setState(() => _reloading = true);
    try {
      final me = await _auth.getUser();
      final clienteId = me?['_id']?.toString();
      if (clienteId != null) {
        final fresh = await _cuponSvc.listarPorCliente(clienteId, soloActivas: true);
        if (!mounted) return;
        setState(() => _items = fresh);
      }
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  // ───────────────────────────── escaneo + asignación
  Future<void> _scanAndLink(BuildContext context) async {
    // 1) abrir escáner
    final code = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanPage()),
    );
    if (code == null || code.trim().isEmpty) return;

    // 2) extraer cuponId del QR
    final cuponId = _extractCuponId(code.trim());
    if (cuponId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código no válido para cuponera.')),
      );
      return;
    }

    // 3) consultar al backend el cupón
    final me = await _auth.getUser();
    final clienteId = me?['_id']?.toString();
    if (clienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión.')),
      );
      return;
    }

    Map<String, dynamic> raw;
    try {
      raw = await _cuponSvc.findByIdRaw(cuponId);
    } on ApiException catch (e) {
      // Solo el texto del error ya procesado por el servicio
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al consultar el cupón.')),
      );
      return;
    }

    final dynamic local = raw['cliente']; // puede ser null o un ObjectId/string
    final yaAsignadoA =
        (local is Map && local['_id'] != null) ? local['_id'].toString() : (local?.toString());

    if (yaAsignadoA == null || yaAsignadoA.isEmpty) {
      // 4) confirmar asignación al cliente actual con bottom sheet
      final ok = await _confirmAssignSheet(
        context,
        title: 'Asignar cuponera',
        message: '¿Deseas ligar esta cuponera a tu cuenta?',
        confirmLabel: 'Sí, asignar',
        cancelLabel: 'Cancelar',
      );
      if (ok != true) return;

      try {
        // OJO: usa el nombre real de tu método (asignarACiente o asignarACliente)
        await _cuponSvc.asignarACliente(clienteId, cuponId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cuponera asignada correctamente!')),
        );
        await _reloadFromServer(); // refresca lista
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo asignar.')),
        );
      }
    } else if (yaAsignadoA == clienteId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta cuponera ya está ligada a tu cuenta.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cuponera ya está ligada a otro cliente.')),
      );
    }
  }

  String? _extractCuponId(String raw) {
    // 24 hex → MongoId directo
    final reHex24 = RegExp(r'^[0-9a-fA-F]{24}$');
    if (reHex24.hasMatch(raw)) return raw;

    // ¿URL con ?cuponId=... o cupon=...?
    try {
      final uri = Uri.parse(raw);
      final id = uri.queryParameters['cuponId'] ?? uri.queryParameters['cupon'];
      if (id != null && reHex24.hasMatch(id)) return id;
    } catch (_) {}

    // ¿JSON con { cuponId / id }?
    try {
      final obj = jsonDecode(raw);
      if (obj is Map) {
        final id = (obj['cuponId'] ?? obj['id'] ?? obj['cupon'])?.toString();
        if (id != null && reHex24.hasMatch(id)) return id;
      }
    } catch (_) {}

    return null;
  }

  // Bottom sheet de confirmación (bonito y azulito)
// Bottom sheet de confirmación (bonito y azulito) + info adicional del cupón
Future<bool?> _confirmAssignSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Asignar',
  String cancelLabel = 'Cancelar',
  Map<String, dynamic>? cuponRaw, // 👈 opcional para mostrar detalles
}) {
  // Extraer datos si vienen
  final ver = cuponRaw?['version'];
  final String versionNombre = (ver is Map && ver['nombre'] != null)
      ? ver['nombre'].toString()
      : '—';
  final String versionDescripcion = (ver is Map && ver['descripcion'] != null)
      ? ver['descripcion'].toString()
      : '';
  final int? sec = (cuponRaw?['secuencial'] is num)
      ? (cuponRaw!['secuencial'] as num).toInt()
      : null;

  String _fmtSec(int? n) => n == null ? 'Nº —' : 'Nº ${n.toString().padLeft(3, '0')}';

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Palette.kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.qr_code_2, color: Colors.black87),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Palette.kTitle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                style: const TextStyle(color: Palette.kMuted),
              ),
            ),

            // 👇 Bloque adicional SOLO si tenemos cuponRaw
            if (cuponRaw != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.kBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Versión
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.layers_outlined, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Versión: $versionNombre',
                            style: const TextStyle(
                              color: Palette.kTitle,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Secuencial
                    Row(
                      children: [
                        const Icon(Icons.tag, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Chip(
                          backgroundColor: Palette.kAccent.withOpacity(0.12),
                          shape: const StadiumBorder(),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                          label: Text(
                            _fmtSec(sec),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    // Descripción (si hay)
                    if (versionDescripcion.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        versionDescripcion,
                        style: const TextStyle(color: Palette.kMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}

  // FAB siempre visible, abajo-derecha
  Widget _buildFab(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 16),
          child: FloatingActionButton.extended(
            onPressed: widget.onAddCuponera ?? () => _scanAndLink(context),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Agregar cuponera'),
            backgroundColor: Palette.kAccent,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Stack(
        children: [
          const Center(
            child: Text('No tienes cuponeras activas', style: TextStyle(color: Palette.kMuted)),
          ),
          _buildFab(context),
        ],
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _reloadFromServer,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _CuponeraTicketCard(
              c: _items[i],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CuponDetalleScreen(cuponId: _items[i].id),
                  ),
                );
              },
            ),
          ),
        ),
        _buildFab(context),
        if (_reloading)
          const Positioned(
            right: 16,
            bottom: 90,
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
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

  // Formatea el secuencial: "Nº 050" (si es numérico) o "Nº ABC"
  String _secFmt(String s) {
    final n = int.tryParse(s);
    final pretty = n != null ? n.toString().padLeft(3, '0') : s;
    return 'Nº $pretty';
  }

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

    final dias = _diasRestantes(c.expiraEl);
    final vencida = c.expiraEl != null && c.expiraEl!.isBefore(DateTime.now());
    final porExpirar = !vencida && dias != null && dias <= 7;

    final statusLabel = vencida ? 'Vencida' : (porExpirar ? 'Por expirar' : 'Activa');
    final statusColor =
        vencida ? Colors.redAccent : (porExpirar ? Colors.amber.shade700 : Colors.green);

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
                  // 👇 NUEVO: badge con el secuencial
                  _SecBadge(label: _secFmt(c.secuencial)),
                  const SizedBox(width: 8),
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

                /*   // 👇 NUEVO: línea con el identificador visible
                  Row(
                    children: [
                      Icon(Icons.tag, color: muted, size: 18),
                      const SizedBox(width: 6),
                      Text('Identificador: ${_secFmt(c.secuencial)}',
                          style: TextStyle(color: muted)),
                    ],
                  ), */

                  const SizedBox(height: 10),

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
                          dias == null
                              ? 'Sin límite'
                              : (vencida ? 'Vencida' : 'Restan $dias días'),
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
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
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
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
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

class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    final codes = cap.barcodes;
    if (codes.isEmpty) return;
    final raw = codes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    _handled = true;
    Navigator.pop(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear cuponera'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),
          // máscara simple
          Align(
            alignment: Alignment.center,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              height: MediaQuery.of(context).size.width * 0.75,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Apunta al código QR',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _SecBadge extends StatelessWidget {
  final String label;
  const _SecBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,                 // contraste sobre el gradiente azul
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,             // texto oscuro legible
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
