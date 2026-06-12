// lib/screens/cupones_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:enjoy/ui/enjoy.dart';

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
    final ec = context.ec;
    final versiones = _versiones;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
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
                color: ec.strokeStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // Título
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Filtrar por versión',
                style: EnjoyTheme.heading(size: 17, color: ec.text),
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
            if (versiones.isNotEmpty) const EnjoyDivider(height: 16),
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
    final ec = context.ec;
    final data = _filtered;
    final total = widget.cupones.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── Barra de filtros ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                // Buscar
                Expanded(
                  flex: 5,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: ec.glass,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ec.stroke),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            color: ec.orangeSoft, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qCtrl,
                            keyboardType: TextInputType.number,
                            cursorColor: ec.orange,
                            decoration: InputDecoration(
                              hintText: 'Secuencial…',
                              hintStyle: EnjoyTheme.body(
                                  size: 13, color: ec.textMute),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isCollapsed: true,
                            ),
                            style: EnjoyTheme.body(size: 13, color: ec.text),
                            onChanged: (v) => setState(() => _q = v.trim()),
                          ),
                        ),
                        if (_q.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _qCtrl.clear();
                              setState(() => _q = '');
                            },
                            child: Icon(Icons.close_rounded,
                                size: 16, color: ec.textMute),
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
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _versionId != null
                            ? ec.orange.withValues(alpha: 0.14)
                            : ec.glass,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _versionId != null
                              ? ec.orange.withValues(alpha: 0.3)
                              : ec.stroke,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bookmark_outline_rounded,
                            size: 16,
                            color: _versionId != null
                                ? ec.orangeSoft
                                : ec.textMute,
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
                              style: EnjoyTheme.body(
                                size: 13,
                                weight: _versionId != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _versionId != null
                                    ? ec.orangeSoft
                                    : ec.textMute,
                              ),
                            ),
                          ),
                          if (_versionId != null)
                            GestureDetector(
                              onTap: () => setState(() => _versionId = null),
                              child: Icon(Icons.close_rounded,
                                  size: 15, color: ec.orangeSoft),
                            )
                          else
                            Icon(Icons.expand_more_rounded,
                                size: 17, color: ec.textMute),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Pill(
                    '${data.length} de $total cupón${total != 1 ? 'es' : ''}',
                    variant: PillVariant.orange,
                    icon: Icons.confirmation_num_rounded,
                    dense: true,
                  ),
                ],
              ),
            ),

          // ── Lista ──
          Expanded(
            child: data.isEmpty
                ? _EmptyState(onScan: _goScan)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final item = data[i];
                      final cupon =
                          (item['cupon'] as Map?)?.cast<String, dynamic>() ??
                              const {};
                      final usuario =
                          (item['usuario'] as Map?)?['nombre']?.toString() ??
                              'Desconocido';
                      final escaneadoPor =
                          (item['escaneadoPor'] as Map?)?['nombre']
                              ?.toString();
                      final sec = cupon['secuencial']?.toString() ?? 'N/A';
                      final version =
                          (cupon['version'] as Map?)?['nombre']?.toString() ??
                              '—';
                      final fechaEscaneo = item['fechaEscaneo']?.toString();

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
        backgroundColor: ec.orange,
        foregroundColor: ec.onAccent,
        elevation: 3,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text('Escanear',
            style: EnjoyTheme.heading(
                size: 14, weight: FontWeight.w700, color: ec.onAccent)),
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
    final ec = context.ec;
    return GlassCard(
      leftAccent: ec.orange,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado: número + estado
          Row(
            children: [
              IconBox(Icons.local_offer_rounded, size: 38, iconSize: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cupón #$secuencial',
                      style: EnjoyTheme.heading(size: 15, color: ec.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      usuario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EnjoyTheme.body(size: 12, color: ec.textMute),
                    ),
                  ],
                ),
              ),
              const Pill('Canjeado',
                  variant: PillVariant.green, dense: true),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(Icons.bookmarks_outlined, version),
          const SizedBox(height: 4),
          if (escaneadoPor != null) ...[
            _InfoRow(Icons.qr_code_scanner_rounded, 'Escaneó: $escaneadoPor'),
            const SizedBox(height: 4),
          ],
          _InfoRow(Icons.access_time_rounded, fechaLabel, muted: false),
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
    final ec = context.ec;
    return Row(
      children: [
        Icon(icon, size: 13, color: ec.textMute),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EnjoyTheme.body(
              size: 12,
              weight: muted ? FontWeight.w400 : FontWeight.w500,
              color: muted ? ec.textMute : ec.textSoft,
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
    final ec = context.ec;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? ec.orange.withValues(alpha: 0.1) : ec.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? ec.orange.withValues(alpha: 0.3) : ec.stroke,
          ),
        ),
        child: Row(
          children: [
            IconBox(
              icon,
              size: 34,
              radius: 10,
              iconSize: 17,
              color: selected ? ec.orangeSoft : ec.textMute,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: EnjoyTheme.body(
                  size: 14,
                  weight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? ec.orangeSoft : ec.text,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 18, color: ec.orangeSoft),
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
    final ec = context.ec;
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
                color: ec.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: ec.orange.withValues(alpha: 0.25)),
              ),
              child: Icon(
                Icons.confirmation_num_outlined,
                size: 44,
                color: ec.orangeSoft,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin cupones',
              style: EnjoyTheme.heading(size: 20, color: ec.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Aún no hay cupones canjeados.\nEscanea un QR para registrar el primero.',
              style: EnjoyTheme.body(size: 13, color: ec.textMute, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            EnjoyButton(
              label: 'Escanear QR',
              icon: Icons.qr_code_scanner_rounded,
              expand: false,
              onPressed: onScan,
            ),
          ],
        ),
      ),
    );
  }
}
