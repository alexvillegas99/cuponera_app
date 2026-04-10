// lib/screens/cupones_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:enjoy/ui/palette.dart';

class CuponesScreen extends StatefulWidget {
  const CuponesScreen({super.key, required this.cupones, this.onScanSuccess});
  final List<Map<String, dynamic>> cupones;
  final void Function(Map<String, dynamic> item)? onScanSuccess;

  @override
  State<CuponesScreen> createState() => _CuponesScreenState();
}

class _CuponesScreenState extends State<CuponesScreen> {
  final _qCtrl = TextEditingController();
  String _q = '';
  String? _versionId;

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  String _formatEcuador(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '—';
    final ec = parsed.toUtc().subtract(const Duration(hours: 5));
    return DateFormat('dd/MM/yyyy hh:mm a', 'es').format(ec);
  }

  List<Map<String, String>> get _versiones {
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

  Future<void> _pickVersion() async {
    final versiones = _versiones;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withOpacity(0.25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // Título
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Filtrar por versión',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: Palette.kTitle,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Opción "Todas"
            _VersionOption(
              label: 'Todas las versiones',
              icon: Icons.layers_outlined,
              selected: _versionId == null,
              onTap: () => Navigator.pop(ctx, '__all__'),
            ),
            if (versiones.isNotEmpty) const Divider(height: 8),
            ...versiones.map((v) => _VersionOption(
                  label: v['nombre'] ?? '—',
                  icon: Icons.bookmark_outline_rounded,
                  selected: _versionId == v['id'],
                  onTap: () => Navigator.pop(ctx, v['id']),
                )),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() => _versionId = selected == '__all__' ? null : selected);
    }
  }

  Future<void> _goScan() async {
    final newItem = await context.push<Map<String, dynamic>>('/scanner');
    if (newItem != null && widget.onScanSuccess != null) {
      widget.onScanSuccess!(newItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtered;
    final total = widget.cupones.length;

    return Scaffold(
      backgroundColor: Palette.kBg,
      body: Column(
        children: [
          // ── Barra de filtros ──
          Container(
            color: Palette.kSurface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                // Buscar
                Expanded(
                  flex: 5,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Palette.kField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Palette.kBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            color: Palette.kMuted, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Secuencial…',
                              hintStyle: TextStyle(
                                  color: Palette.kMuted, fontSize: 13),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (v) => setState(() => _q = v.trim()),
                          ),
                        ),
                        if (_q.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _qCtrl.clear();
                              setState(() => _q = '');
                            },
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: Palette.kMuted),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filtro versión — bottom sheet
                Expanded(
                  flex: 5,
                  child: GestureDetector(
                    onTap: _pickVersion,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _versionId != null
                            ? Palette.kAccent.withOpacity(0.08)
                            : Palette.kField,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _versionId != null
                              ? Palette.kAccent.withOpacity(0.4)
                              : Palette.kBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bookmark_outline_rounded,
                            size: 16,
                            color: _versionId != null
                                ? Palette.kAccent
                                : Palette.kMuted,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              _versionId != null
                                  ? (_versiones.firstWhere(
                                      (v) => v['id'] == _versionId,
                                      orElse: () => {'nombre': '—'},
                                    )['nombre'] ??
                                      '—')
                                  : 'Versión',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: _versionId != null
                                    ? Palette.kAccent
                                    : Palette.kMuted,
                                fontWeight: _versionId != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (_versionId != null)
                            GestureDetector(
                              onTap: () => setState(() => _versionId = null),
                              child: const Icon(Icons.close_rounded,
                                  size: 15, color: Palette.kAccent),
                            )
                          else
                            const Icon(Icons.expand_more_rounded,
                                size: 17, color: Palette.kMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Contador ──
          if (total > 0)
            Container(
              color: Palette.kSurface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Palette.kAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.confirmation_num_rounded,
                            size: 13, color: Palette.kAccent),
                        const SizedBox(width: 5),
                        Text(
                          '${data.length} de $total cupón${total != 1 ? 'es' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Palette.kAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: Palette.kBorder),

          // ── Lista ──
          Expanded(
            child: data.isEmpty
                ? _EmptyState(onScan: _goScan)
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: data.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final item =
                          data[i] as Map<String, dynamic>;
                      final cupon =
                          (item['cupon'] as Map?)
                              ?.cast<String, dynamic>() ??
                          const {};
                      final usuario =
                          (item['usuario'] as Map?)?['nombre']
                              ?.toString() ??
                          'Desconocido';
                      final escaneadoPor =
                          (item['escaneadoPor'] as Map?)?['nombre']
                              ?.toString();
                      final sec =
                          cupon['secuencial']?.toString() ?? 'N/A';
                      final version =
                          (cupon['version'] as Map?)?['nombre']
                              ?.toString() ??
                          '—';
                      final fechaEscaneo =
                          item['fechaEscaneo']?.toString();

                      return _CouponCard(
                        secuencial: sec,
                        version: version,
                        usuario: usuario,
                        escaneadoPor: escaneadoPor,
                        fechaLabel: _formatEcuador(fechaEscaneo),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goScan,
        backgroundColor: Palette.kAccent,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Escanear',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Card de cupón
// ─────────────────────────────────────────────────────────────────

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.secuencial,
    required this.version,
    required this.usuario,
    required this.fechaLabel,
    this.escaneadoPor,
  });

  final String secuencial;
  final String version;
  final String usuario;
  final String? escaneadoPor;
  final String fechaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Row(
        children: [
          // Franja naranja izquierda
          Container(
            width: 5,
            height: 110,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Palette.kAccent, Palette.kAccentLight],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),

          // Ícono central
          Container(
            width: 52,
            height: 110,
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Palette.kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                size: 20,
                color: Palette.kAccent,
              ),
            ),
          ),

          // Contenido
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado: número + check
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Cupón #$secuencial',
                          style: const TextStyle(
                            color: Palette.kTitle,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 12, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'Canjeado',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Versión
                  _InfoRow(Icons.bookmarks_outlined, version),
                  const SizedBox(height: 3),

                  // Responsable
                  _InfoRow(Icons.store_rounded, usuario),
                  const SizedBox(height: 3),

                  // Quién escaneó (si difiere)
                  if (escaneadoPor != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: _InfoRow(
                          Icons.qr_code_scanner_rounded, 'Escaneó: $escaneadoPor'),
                    ),

                  // Fecha
                  _InfoRow(Icons.access_time_rounded, fechaLabel,
                      muted: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text, {this.muted = true});
  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Palette.kMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: muted ? Palette.kMuted : Palette.kTitle,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Opción de versión en bottom sheet
// ─────────────────────────────────────────────────────────────────

class _VersionOption extends StatelessWidget {
  const _VersionOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Palette.kAccent.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Palette.kAccent.withOpacity(0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? Palette.kAccent.withOpacity(0.12)
                    : Palette.kField,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 17,
                color: selected ? Palette.kAccent : Palette.kMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Palette.kAccent : Palette.kTitle,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  size: 18, color: Palette.kAccent),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Estado vacío
// ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Palette.kAccent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.confirmation_num_outlined,
                size: 44,
                color: Palette.kAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sin cupones',
              style: TextStyle(
                color: Palette.kTitle,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aún no hay cupones canjeados.\nEscanea un QR para registrar el primero.',
              style: TextStyle(color: Palette.kMuted, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onScan,
              style: FilledButton.styleFrom(
                backgroundColor: Palette.kAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text(
                'Escanear QR',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
