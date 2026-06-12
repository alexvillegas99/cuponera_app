import 'dart:async';

import 'package:enjoy/services/cupones_admin_service.dart';
import 'package:enjoy/ui/enjoy.dart';
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
    final ec = context.ec;
    return Column(
      children: [
        // ── Buscador ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            cursorColor: ec.orange,
            style: EnjoyTheme.body(size: 14, color: ec.text),
            decoration: InputDecoration(
              hintText: 'Buscar por secuencial, cliente o estado...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () { _searchCtrl.clear(); _cargar(reset: true); },
                    )
                  : null,
            ),
          ),
        ),

        // ── Contador ──────────────────────────────────────────────
        if (!_loading && _error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text(
                  '$_total cupón${_total != 1 ? 'es' : ''} asignado${_total != 1 ? 's' : ''}',
                  style: EnjoyTheme.body(size: 12, weight: FontWeight.w500, color: ec.textMute),
                ),
                if (_totalPages > 1) ...[
                  const Spacer(),
                  Text('Página $_page de $_totalPages',
                      style: EnjoyTheme.body(size: 12, color: ec.textMute)),
                ],
              ],
            ),
          ),

        // ── Contenido ─────────────────────────────────────────────
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: ec.orange))
              : _error != null
                  ? _ErrorRetry(message: _error!, onRetry: _cargar)
                  : _cupones.isEmpty
                      ? const _Empty()
                      : RefreshIndicator(
                          color: ec.orange,
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

  PillVariant get _estadoPill {
    switch (_estado) {
      case 'activo': return PillVariant.green;
      case 'bloqueado': return PillVariant.red;
      default: return PillVariant.glass;
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
    final ec = context.ec;
    final secuencial = cupon['secuencial'];
    final escaneos = cupon['numeroDeEscaneos'] ?? 0;
    final vencimiento = cupon['fechaVencimiento']?.toString();
    final ultimoScan = cupon['ultimoScaneo']?.toString();
    final creacion = cupon['createdAt']?.toString();

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera: cliente + estado + secuencial ────────────
          Row(
            children: [
              EnjoyAvatar(_nombreCliente, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nombreCliente,
                        style: EnjoyTheme.heading(size: 14, color: ec.text),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(_correoCliente,
                        style: EnjoyTheme.body(size: 11, color: ec.textMute),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Pill(_estadoLabel, variant: _estadoPill, dense: true),
                  if (secuencial != null) ...[
                    const SizedBox(height: 4),
                    Text('#$secuencial',
                        style: EnjoyTheme.body(size: 11, weight: FontWeight.w600, color: ec.textMute)),
                  ],
                ],
              ),
            ],
          ),

          const EnjoyDivider(height: 20),

          // ── Cuponera ───────────────────────────────────────────
          _InfoRow(
            icon: Icons.confirmation_num_rounded,
            label: 'Cuponera',
            value: _versionNombre,
            accent: true,
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
    );
  }
}

// ── Fila de info ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  const _InfoRow({required this.icon, required this.label, required this.value, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final hl = accent ? ec.orangeSoft : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: hl ?? ec.textMute),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: Text(label, style: EnjoyTheme.body(size: 12, color: ec.textMute)),
          ),
          Expanded(
            child: Text(value,
                style: EnjoyTheme.body(size: 12, weight: FontWeight.w600, color: hl ?? ec.text),
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
    final ec = context.ec;
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
              style: EnjoyTheme.heading(size: 14, weight: FontWeight.w600, color: ec.text),
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
    final ec = context.ec;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          gradient: enabled ? ec.accentGradient : null,
          color: enabled ? null : ec.glass,
          borderRadius: BorderRadius.circular(11),
          border: enabled ? null : Border.all(color: ec.stroke),
        ),
        child: Icon(icon, size: 20, color: enabled ? ec.onAccent : ec.textMute),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBox(Icons.confirmation_num_outlined, size: 72, radius: 20, iconSize: 36),
          const SizedBox(height: 14),
          Text('Sin cupones asignados',
              style: EnjoyTheme.heading(size: 16, color: ec.text)),
          const SizedBox(height: 4),
          Text('No se encontraron cupones con ese filtro.',
              style: EnjoyTheme.body(size: 13, color: ec.textMute)),
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
    final ec = context.ec;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBox(Icons.wifi_off_rounded, size: 64, radius: 18, iconSize: 32, color: ec.red),
          const SizedBox(height: 14),
          Text(message, style: EnjoyTheme.body(size: 13, color: ec.textMute)),
          const SizedBox(height: 16),
          EnjoyButton(
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            expand: false,
            onPressed: onRetry,
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
