import 'package:enjoy/services/solicitudes_admin_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

class SolicitudesAdminScreen extends StatefulWidget {
  const SolicitudesAdminScreen({super.key});

  @override
  State<SolicitudesAdminScreen> createState() => _SolicitudesAdminScreenState();
}

class _SolicitudesAdminScreenState extends State<SolicitudesAdminScreen> {
  final _svc = SolicitudesAdminService();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _filtroEstado = '';

  static const _estados = [
    (value: '', label: 'Todos'),
    (value: 'PENDIENTE', label: 'Pendiente'),
    (value: 'APROBADO', label: 'Aprobado'),
    (value: 'RECHAZADO', label: 'Rechazado'),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _svc.listar(estado: _filtroEstado.isEmpty ? null : _filtroEstado);
      final lista = res['items'];
      if (mounted) {
        setState(() {
          _items = lista is List ? List<Map<String, dynamic>>.from(lista) : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'No se pudieron cargar las solicitudes.'; _loading = false; });
    }
  }

  Future<void> _aprobar(Map<String, dynamic> sol) async {
    final id = sol['_id']?.toString() ?? '';
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        titulo: 'Aprobar solicitud',
        mensaje: '¿Aprobar la solicitud de "${sol['nombreCliente'] ?? 'cliente'}" para "${sol['cuponeraNombre'] ?? 'cuponera'}"?',
        confirmLabel: 'Aprobar',
        confirmVariant: EnjoyButtonVariant.green,
      ),
    );
    if (ok != true) return;

    try {
      await _svc.actualizarEstado(id, {'estado': 'APROBADO'});
      if (mounted) {
        _snack('Solicitud aprobada', success: true);
        _aplicarEstadoLocal(sol, 'APROBADO');
      }
    } catch (_) {
      if (mounted) _snack('Error al aprobar la solicitud');
    }
  }

  /// Actualiza la solicitud en memoria sin recargar toda la lista.
  /// Si el filtro activo ya no incluye el nuevo estado, la quita de la vista;
  /// si es "Todos", solo cambia su estado (la tarjeta se re-renderiza).
  void _aplicarEstadoLocal(
    Map<String, dynamic> sol,
    String nuevoEstado, {
    String? notaAdmin,
  }) {
    final idx = _items.indexWhere((e) => e['_id'] == sol['_id']);
    if (idx == -1) return;
    setState(() {
      if (_filtroEstado.isNotEmpty && _filtroEstado != nuevoEstado) {
        _items.removeAt(idx);
      } else {
        _items[idx] = {
          ..._items[idx],
          'estado': nuevoEstado,
          if (notaAdmin != null && notaAdmin.trim().isNotEmpty)
            'notaAdmin': notaAdmin.trim(),
        };
      }
    });
  }

  Future<void> _rechazar(Map<String, dynamic> sol, String notaAdmin) async {
    final id = sol['_id']?.toString() ?? '';
    if (id.isEmpty) return;

    try {
      final data = <String, dynamic>{'estado': 'RECHAZADO'};
      if (notaAdmin.trim().isNotEmpty) data['notaAdmin'] = notaAdmin.trim();
      await _svc.actualizarEstado(id, data);
      if (mounted) {
        _snack('Solicitud rechazada', info: true);
        _aplicarEstadoLocal(sol, 'RECHAZADO', notaAdmin: notaAdmin);
      }
    } catch (_) {
      if (mounted) _snack('Error al rechazar la solicitud');
    }
  }

  void _snack(String msg, {bool success = false, bool info = false}) {
    final ec = context.ec;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? ec.green : info ? ec.orange : ec.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return '—';
    try {
      final d = DateTime.parse(fecha).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return fecha;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    if (_loading) return Center(child: CircularProgressIndicator(color: ec.orange));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBox(Icons.wifi_off_rounded, size: 64, radius: 18, iconSize: 32, color: ec.red),
            const SizedBox(height: 14),
            Text(_error!, style: EnjoyTheme.body(size: 13, color: ec.textMute)),
            const SizedBox(height: 16),
            EnjoyButton(
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: _cargar,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Filtros de estado ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _estados.map((e) {
                final sel = _filtroEstado == e.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pill(
                    e.label,
                    variant: sel ? _estadoPill(e.value) : PillVariant.glass,
                    onTap: () {
                      setState(() => _filtroEstado = e.value);
                      _cargar();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── Contador ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${_items.length} solicitud${_items.length != 1 ? 'es' : ''}',
                style: EnjoyTheme.body(size: 12, weight: FontWeight.w500, color: ec.textMute),
              ),
            ],
          ),
        ),

        // ── Lista ──────────────────────────────────────────────────
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconBox(Icons.receipt_long_rounded, size: 72, radius: 20, iconSize: 36),
                      const SizedBox(height: 14),
                      Text('Sin solicitudes', style: EnjoyTheme.heading(size: 16, color: ec.text)),
                      const SizedBox(height: 4),
                      Text('No hay solicitudes para este filtro.', style: EnjoyTheme.body(size: 13, color: ec.textMute)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: ec.orange,
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _SolicitudCard(
                      key: ValueKey(_items[i]['_id']),
                      sol: _items[i],
                      formatFecha: _formatFecha,
                      onAprobar: () => _aprobar(_items[i]),
                      onRechazar: (nota) => _rechazar(_items[i], nota),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Helpers de estado (compartidos) ──────────────────────────────────────────

PillVariant _estadoPill(String estado) {
  switch (estado) {
    case 'APROBADO': return PillVariant.green;
    case 'RECHAZADO': return PillVariant.red;
    case 'PENDIENTE': return PillVariant.orange;
    default: return PillVariant.orange;
  }
}

Color _estadoColor(BuildContext context, String estado) {
  final ec = context.ec;
  switch (estado) {
    case 'APROBADO': return ec.green;
    case 'RECHAZADO': return ec.red;
    default: return ec.orange;
  }
}

// ── Card de solicitud ────────────────────────────────────────────────────────

class _SolicitudCard extends StatefulWidget {
  final Map<String, dynamic> sol;
  final String Function(String?) formatFecha;
  final Future<void> Function() onAprobar;
  final Future<void> Function(String nota) onRechazar;

  const _SolicitudCard({
    super.key,
    required this.sol,
    required this.formatFecha,
    required this.onAprobar,
    required this.onRechazar,
  });

  @override
  State<_SolicitudCard> createState() => _SolicitudCardState();
}

class _SolicitudCardState extends State<_SolicitudCard> {
  final _notaCtrl = TextEditingController();

  /// Acción en curso: 'aprobar' | 'rechazar' | null. Bloquea ambos botones
  /// y muestra spinner en el que se tocó (evita doble envío).
  String? _accion;

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _ejecutar(String accion, Future<void> Function() fn) async {
    if (_accion != null) return;
    setState(() => _accion = accion);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _accion = null);
    }
  }

  IconData get _estadoIcon {
    switch (_estado) {
      case 'APROBADO': return Icons.check_circle_rounded;
      case 'RECHAZADO': return Icons.cancel_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String get _estadoLabel {
    switch (_estado) {
      case 'APROBADO': return 'Aprobada';
      case 'RECHAZADO': return 'Rechazada';
      default: return 'Pendiente';
    }
  }

  String get _estado => (widget.sol['estado'] ?? 'PENDIENTE').toString();

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final sol = widget.sol;
    final color = _estadoColor(context, _estado);
    final esPendiente = _estado == 'PENDIENTE';

    return GlassCard(
      padding: const EdgeInsets.all(14),
      leftAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera: cliente + estado ──────────────────────
          Row(
            children: [
              IconBox(_estadoIcon, size: 38, radius: 11, iconSize: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (sol['nombreCliente'] ?? 'Cliente desconocido').toString(),
                      style: EnjoyTheme.heading(size: 14, color: ec.text),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    if (sol['emailCliente'] != null)
                      Text(
                        sol['emailCliente'].toString(),
                        style: EnjoyTheme.body(size: 11, color: ec.textMute),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Pill(_estadoLabel, variant: _estadoPill(_estado), dense: true),
            ],
          ),

          const EnjoyDivider(height: 20),

          // ── Detalles ─────────────────────────────────────────
          _DetailRow(icon: Icons.confirmation_num_rounded, label: 'Cuponera', value: sol['cuponeraNombre']?.toString() ?? '—'),
          if (sol['cuponeraPrecio'] != null)
            _DetailRow(icon: Icons.attach_money_rounded, label: 'Precio', value: '\$${sol['cuponeraPrecio']}'),
          if (sol['montoTransferido'] != null)
            _DetailRow(icon: Icons.receipt_rounded, label: 'Transferido', value: '\$${sol['montoTransferido']}'),
          if (sol['telefonoCliente'] != null)
            _DetailRow(icon: Icons.phone_rounded, label: 'Teléfono', value: sol['telefonoCliente'].toString()),
          _DetailRow(icon: Icons.calendar_today_rounded, label: 'Fecha', value: widget.formatFecha(sol['createdAt']?.toString())),

          if (sol['observaciones'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ec.glass,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ec.stroke),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 13, color: ec.textMute),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Obs: ${sol['observaciones']}',
                      style: EnjoyTheme.body(size: 12, color: ec.textMute),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (sol['notaAdmin'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ec.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ec.red.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 13, color: ec.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Nota admin: ${sol['notaAdmin']}',
                      style: EnjoyTheme.body(size: 12, color: ec.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Comprobante ──────────────────────────────────────
          if (sol['comprobanteUrl'] != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _verImagen(context, sol['comprobanteUrl'].toString()),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: EnjoyImage(
                  sol['comprobanteUrl'].toString(),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: ec.glass,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ec.stroke),
                    ),
                    child: Center(child: Icon(Icons.broken_image_rounded, color: ec.textMute)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Toca para ampliar el comprobante',
                  style: EnjoyTheme.body(size: 10, color: ec.textMute)),
            ),
          ],

          // ── Acciones (solo si pendiente) ─────────────────────
          if (esPendiente) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _notaCtrl,
              cursorColor: ec.orange,
              style: EnjoyTheme.body(size: 13, color: ec.text),
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Nota de rechazo (opcional)',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: EnjoyButton(
                    label: 'Rechazar',
                    icon: Icons.close_rounded,
                    variant: EnjoyButtonVariant.red,
                    dense: true,
                    loading: _accion == 'rechazar',
                    onPressed: _accion != null
                        ? null
                        : () => _ejecutar(
                            'rechazar', () => widget.onRechazar(_notaCtrl.text)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EnjoyButton(
                    label: 'Aprobar',
                    icon: Icons.check_rounded,
                    variant: EnjoyButtonVariant.green,
                    dense: true,
                    loading: _accion == 'aprobar',
                    onPressed: _accion != null
                        ? null
                        : () => _ejecutar('aprobar', widget.onAprobar),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _verImagen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: EnjoyImage(
              url,
              fit: BoxFit.contain,
              errorWidget: const SizedBox(
                height: 200,
                child: Center(child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fila de detalle ─────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: ec.textMute),
          const SizedBox(width: 6),
          Text('$label: ', style: EnjoyTheme.body(size: 12, color: ec.textMute)),
          Expanded(
            child: Text(value,
                style: EnjoyTheme.body(size: 12, weight: FontWeight.w600, color: ec.text),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Diálogo de confirmación ──────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final String confirmLabel;
  final EnjoyButtonVariant confirmVariant;

  const _ConfirmDialog({
    required this.titulo,
    required this.mensaje,
    required this.confirmLabel,
    required this.confirmVariant,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: GlassCard(
        blur: false,
        color: ec.surfaceTop,
        radius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: EnjoyTheme.heading(size: 16, weight: FontWeight.w800, color: ec.text)),
            const SizedBox(height: 8),
            Text(mensaje, style: EnjoyTheme.body(size: 13, color: ec.textSoft)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: EnjoyButton(
                    label: 'Cancelar',
                    variant: EnjoyButtonVariant.ghost,
                    dense: true,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EnjoyButton(
                    label: confirmLabel,
                    variant: confirmVariant,
                    dense: true,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
