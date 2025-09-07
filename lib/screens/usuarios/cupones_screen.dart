// lib/screens/cupones_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:enjoy/ui/palette.dart';

class CuponesScreen extends StatefulWidget {
  const CuponesScreen({super.key, required this.cupones, this.onAfterScan});
  final List<Map<String, dynamic>> cupones;
  final Future<void> Function()? onAfterScan; // 👈 NUEVO
  @override
  State<CuponesScreen> createState() => _CuponesScreenState();
}

class _CuponesScreenState extends State<CuponesScreen> {
  final _qCtrl = TextEditingController();
  String _q = '';
  String? _versionId; // filtro por versión

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  String _formatEcuador(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '—';
    // Quito UTC-5
    final ec = parsed.toUtc().subtract(const Duration(hours: 5));
    return DateFormat('dd/MM/yyyy hh:mm a', 'es').format(ec);
  }

  List<Map<String, String>> get _versiones {
    // Construye lista única de versiones presentes: [{id, nombre}]
    final set = <String, Map<String, String>>{};
    for (final item in widget.cupones) {
      final version = (item['cupon']?['version'] as Map?) ?? const {};
      final id = version['_id']?.toString();
      final nombre = version['nombre']?.toString();
      if (id != null && nombre != null) {
        set[id] = {'id': id, 'nombre': nombre};
      }
    }
    final list = set.values.toList();
    list.sort((a, b) => a['nombre']!.compareTo(b['nombre']!));
    return list;
  }

  List<Map<String, dynamic>> get _filtered {
    return widget.cupones.where((c) {
      final cupon = c['cupon'] as Map<String, dynamic>? ?? const {};
      final version = cupon['version'] as Map<String, dynamic>? ?? const {};
      final sec = cupon['secuencial']?.toString() ?? '';
      final matchesText = _q.isEmpty || sec.contains(_q);
      final matchesVersion =
          _versionId == null || version['_id']?.toString() == _versionId;
      return matchesText && matchesVersion;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtered;
    final isEmpty = data.isEmpty;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Palette.kBg,
      resizeToAvoidBottomInset: true,

      body: Column(
        children: [
          // ——— Filtros ———
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                // Buscar por secuencial
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Palette.kField,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Palette.kBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Palette.kMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Buscar por secuencial…',
                              hintStyle: TextStyle(color: Palette.kMuted),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                            onChanged: (v) => setState(() => _q = v.trim()),
                          ),
                        ),
                        if (_q.isNotEmpty)
                          IconButton(
                            tooltip: 'Limpiar',
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Palette.kMuted,
                            ),
                            onPressed: () {
                              _qCtrl.clear();
                              setState(() => _q = '');
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Filtro por versión
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Palette.kField,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Palette.kBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _versionId,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Palette.kMuted,
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todas las versiones'),
                          ),
                          ..._versiones.map(
                            (v) => DropdownMenuItem(
                              value: v['id'] as String?,
                              child: Text((v['nombre'] ?? '—').toString()),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _versionId = v),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ——— Lista / Empty ———
          Expanded(
            child: isEmpty
                ? AnimatedPadding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    duration: const Duration(milliseconds: 150),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: _EmptyState(
                        onScan: () async {
                          // 👈 puede ser async sin cambiar la firma
                          final ok = await context.push<bool>('/scanner');
                          if (ok == true && widget.onAfterScan != null) {
                            await widget.onAfterScan!();
                          }
                        },
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 100 + bottomInset),
                    itemCount: data.length,
                    itemBuilder: (_, i) {
                      final item = data[i] as Map<String, dynamic>;
                      final cupon =
                          (item['cupon'] as Map?)?.cast<String, dynamic>() ??
                          const {};
                      final usuario =
                          (item['usuario'] as Map?)?['nombre']?.toString() ??
                          'Desconocido';
                      final sec = cupon['secuencial']?.toString() ?? 'N/A';
                      final version =
                          (cupon['version'] as Map?)?['nombre']?.toString() ??
                          '—';
                      final estado = cupon['estado']?.toString();
                      final fechaEscaneo = item['fechaEscaneo']?.toString();

                      return _CouponCard(
                        secuencial: sec,
                        version: version,
                        estado: estado,
                        usuario: usuario,
                        // Fecha en 2 líneas (por si se alarga)
                        escaneoLabel:
                            'Escaneado el ${_formatEcuador(fechaEscaneo)}',
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ok = await context.push<bool>('/scanner'); // 👈 esperamos bool
          if (ok == true && widget.onAfterScan != null) {
            await widget.onAfterScan!(); // 👈 recarga real desde backend
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Listado actualizado')),
            );
          }
        },
        backgroundColor: Palette.kPrimary,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.secuencial,
    required this.version,
    required this.estado,
    required this.usuario,
    required this.escaneoLabel,
  });

  final String secuencial;
  final String version;
  final String? estado;
  final String usuario;
  final String escaneoLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          // Franja
          Container(
            width: 86,
            height: 135,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              gradient: LinearGradient(
                colors: [Palette.kPrimary, Palette.kAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.local_offer_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),

          // separador punteado
          SizedBox(
            width: 14,
            height: 120,
            child: CustomPaint(painter: _DashPainter(color: Palette.kBorder)),
          ),

          // contenido
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + chips
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Cupón #$secuencial',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Palette.kTitle,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Versión
                  Row(
                    children: [
                      const Icon(
                        Icons.bookmarks_outlined,
                        size: 16,
                        color: Palette.kMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          version,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Palette.kTitle,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Usuario
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Palette.kMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          usuario,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Palette.kTitle,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Fecha de escaneo (hasta 2 líneas)
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Palette.kMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          escaneoLabel,
                          maxLines: 2, // 👈 hasta 2 líneas
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Palette.kTitle,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashHeight = 6.0, dashSpace = 4.0;
    double y = 8, x = size.width / 2;
    while (y < size.height - 8) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dashHeight), paint);
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Palette.kSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Palette.kBorder),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 24,
                    color: Colors.black.withOpacity(0.05),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                size: 56,
                color: Palette.kPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin resultados',
              style: TextStyle(
                color: Palette.kTitle,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Intenta con otro secuencial o cambia la versión.',
              style: TextStyle(color: Palette.kSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Palette.kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'Escanear QR',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
