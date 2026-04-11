import 'dart:async';

import 'package:enjoy/services/cupones_admin_service.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:flutter/material.dart';

class CuponesAsignadosScreen extends StatefulWidget {
  const CuponesAsignadosScreen({super.key});

  @override
  State<CuponesAsignadosScreen> createState() => _CuponesAsignadosScreenState();
}

class _CuponesAsignadosScreenState extends State<CuponesAsignadosScreen> {
  final _svc = CuponesAdminService();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _cupones = [];
  bool _loading = true;
  String? _error;

  int _page = 1;
  int _total = 0;
  static const _limit = 15;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _svc.listar(
        search: _searchCtrl.text.trim(),
        page: _page,
        limit: _limit,
      );
      final lista = res['data'] ?? res['items'] ?? [];
      if (mounted) {
        setState(() {
          _cupones = lista is List ? List<Map<String, dynamic>>.from(lista) : [];
          _total = (res['total'] ?? 0) as int;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'No se pudieron cargar los cupones.'; _loading = false; });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _cargar(reset: true));
  }

  int get _totalPages => (_total / _limit).ceil();

  String _formatFecha(String? raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Buscador ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Palette.kTitle, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por secuencial, cliente o estado...',
              hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Palette.kMuted, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Palette.kMuted),
                      onPressed: () { _searchCtrl.clear(); _cargar(reset: true); },
                    )
                  : null,
              filled: true,
              fillColor: Palette.kSurface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent)),
            ),
          ),
        ),

        // ── Contador ──────────────────────────────────────────────
        if (!_loading && _error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Text(
                  '$_total cupón${_total != 1 ? 'es' : ''} asignado${_total != 1 ? 's' : ''}',
                  style: const TextStyle(color: Palette.kMuted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                if (_totalPages > 1) ...[
                  const Spacer(),
                  Text('Página $_page de $_totalPages',
                      style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
                ],
              ],
            ),
          ),

        // ── Contenido ─────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Palette.kAccent))
              : _error != null
                  ? _ErrorRetry(message: _error!, onRetry: _cargar)
                  : _cupones.isEmpty
                      ? const _Empty()
                      : RefreshIndicator(
                          color: Palette.kAccent,
                          onRefresh: () => _cargar(reset: true),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: _cupones.length + (_totalPages > 1 ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              if (i == _cupones.length) {
                                return _Paginacion(
                                  page: _page,
                                  totalPages: _totalPages,
                                  onPrev: _page > 1
                                      ? () { setState(() => _page--); _cargar(); }
                                      : null,
                                  onNext: _page < _totalPages
                                      ? () { setState(() => _page++); _cargar(); }
                                      : null,
                                );
                              }
                              return _CuponCard(
                                cupon: _cupones[i],
                                formatFecha: _formatFecha,
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

// ── Card de cupón ────────────────────────────────────────────────────────────

class _CuponCard extends StatelessWidget {
  final Map<String, dynamic> cupon;
  final String Function(String?) formatFecha;

  const _CuponCard({required this.cupon, required this.formatFecha});

  String get _nombreCliente {
    final c = cupon['cliente'];
    if (c is Map) {
      final n = (c['nombres'] ?? c['nombre'] ?? '').toString().trim();
      final a = (c['apellidos'] ?? '').toString().trim();
      return [n, a].where((s) => s.isNotEmpty).join(' ').ifEmpty('Cliente desconocido');
    }
    return 'Cliente desconocido';
  }

  String get _correoCliente {
    final c = cupon['cliente'];
    return c is Map ? (c['email'] ?? c['correo'] ?? '—').toString() : '—';
  }

  String get _cedulaCliente {
    final c = cupon['cliente'];
    return c is Map ? (c['identificacion'] ?? '—').toString() : '—';
  }

  String get _versionNombre {
    final v = cupon['version'];
    if (v is Map) return (v['nombre'] ?? '—').toString();
    return '—';
  }

  String get _estado => (cupon['estado'] ?? '').toString().toLowerCase();

  Color get _estadoColor {
    switch (_estado) {
      case 'activo': return const Color(0xFF16A34A);
      case 'bloqueado': return const Color(0xFFDC2626);
      default: return Palette.kMuted;
    }
  }

  String get _estadoLabel {
    switch (_estado) {
      case 'activo': return 'Activo';
      case 'bloqueado': return 'Bloqueado';
      default: return 'Inactivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final secuencial = cupon['secuencial'];
    final escaneos = cupon['numeroDeEscaneos'] ?? 0;
    final vencimiento = cupon['fechaVencimiento']?.toString();
    final ultimoScan = cupon['ultimoScaneo']?.toString();
    final creacion = cupon['createdAt']?.toString();
    final color = _estadoColor;
    final initial = _nombreCliente.isNotEmpty ? _nombreCliente[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera: cliente + estado + secuencial ────────────
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Palette.kAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(initial,
                        style: const TextStyle(color: Palette.kAccent, fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nombreCliente,
                          style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(_correoCliente,
                          style: const TextStyle(color: Palette.kMuted, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(_estadoLabel,
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    if (secuencial != null) ...[
                      const SizedBox(height: 4),
                      Text('#$secuencial',
                          style: const TextStyle(color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Palette.kBorder),
            const SizedBox(height: 10),

            // ── Cuponera ───────────────────────────────────────────
            _InfoRow(
              icon: Icons.confirmation_num_rounded,
              label: 'Cuponera',
              value: _versionNombre,
              color: Palette.kAccent,
            ),

            // ── CI del cliente ─────────────────────────────────────
            if (_cedulaCliente != '—')
              _InfoRow(icon: Icons.badge_rounded, label: 'Cédula', value: _cedulaCliente),

            // ── Escaneos ───────────────────────────────────────────
            _InfoRow(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Escaneos',
              value: escaneos.toString(),
            ),

            // ── Fechas ─────────────────────────────────────────────
            if (creacion != null)
              _InfoRow(icon: Icons.calendar_today_rounded, label: 'Asignado', value: formatFecha(creacion)),
            if (vencimiento != null)
              _InfoRow(icon: Icons.event_rounded, label: 'Vence', value: formatFecha(vencimiento)),
            if (ultimoScan != null)
              _InfoRow(
                icon: Icons.access_time_rounded,
                label: 'Último scan',
                value: formatFecha(ultimoScan),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Fila de info ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color ?? Palette.kMuted),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: color ?? Palette.kTitle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Paginación ───────────────────────────────────────────────────────────────

class _Paginacion extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _Paginacion({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageBtn(
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
            enabled: onPrev != null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '$page / $totalPages',
              style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          _PageBtn(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
            enabled: onNext != null,
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _PageBtn({required this.icon, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? Palette.kAccent : Palette.kField,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: enabled ? Colors.white : Palette.kBorder),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.confirmation_num_outlined, size: 48, color: Palette.kBorder),
          SizedBox(height: 12),
          Text('Sin cupones asignados',
              style: TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: 4),
          Text('No se encontraron cupones con ese filtro.',
              style: TextStyle(color: Palette.kMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: Palette.kAccent, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ── Extension helper ─────────────────────────────────────────────────────────

extension _StringEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
