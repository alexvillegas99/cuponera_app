import 'package:enjoy/services/solicitudes_admin_service.dart';
import 'package:enjoy/ui/palette.dart';
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
        confirmColor: const Color(0xFF16A34A),
      ),
    );
    if (ok != true) return;

    try {
      await _svc.actualizarEstado(id, {'estado': 'APROBADO'});
      if (mounted) {
        _snack('Solicitud aprobada', success: true);
        _cargar();
      }
    } catch (_) {
      if (mounted) _snack('Error al aprobar la solicitud');
    }
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
        _cargar();
      }
    } catch (_) {
      if (mounted) _snack('Error al rechazar la solicitud');
    }
  }

  void _snack(String msg, {bool success = false, bool info = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green.shade700 : info ? Colors.orange.shade700 : Colors.red.shade700,
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: Palette.kAccent));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(backgroundColor: Palette.kAccent, foregroundColor: Colors.white),
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
                return GestureDetector(
                  onTap: () {
                    setState(() => _filtroEstado = e.value);
                    _cargar();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _estadoColor(e.value) : Palette.kSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? _estadoColor(e.value) : Palette.kBorder),
                    ),
                    child: Text(
                      e.label,
                      style: TextStyle(
                        color: sel ? Colors.white : Palette.kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── Contador ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Text(
                '${_items.length} solicitud${_items.length != 1 ? 'es' : ''}',
                style: const TextStyle(color: Palette.kMuted, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        // ── Lista ──────────────────────────────────────────────────
        Expanded(
          child: _items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 48, color: Palette.kBorder),
                      SizedBox(height: 12),
                      Text('Sin solicitudes', style: TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('No hay solicitudes para este filtro.', style: TextStyle(color: Palette.kMuted, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: Palette.kAccent,
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _SolicitudCard(
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

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'APROBADO': return const Color(0xFF16A34A);
      case 'RECHAZADO': return const Color(0xFFDC2626);
      case 'PENDIENTE': return const Color(0xFFD97706);
      default: return Palette.kAccent;
    }
  }
}

// ── Card de solicitud ────────────────────────────────────────────────────────

class _SolicitudCard extends StatefulWidget {
  final Map<String, dynamic> sol;
  final String Function(String?) formatFecha;
  final VoidCallback onAprobar;
  final void Function(String nota) onRechazar;

  const _SolicitudCard({
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

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Color get _estadoColor {
    switch (_estado) {
      case 'APROBADO': return const Color(0xFF16A34A);
      case 'RECHAZADO': return const Color(0xFFDC2626);
      default: return const Color(0xFFD97706);
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
    final sol = widget.sol;
    final color = _estadoColor;
    final esPendiente = _estado == 'PENDIENTE';

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
            // ── Cabecera: cliente + estado ──────────────────────
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_estadoIcon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (sol['nombreCliente'] ?? 'Cliente desconocido').toString(),
                        style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      if (sol['emailCliente'] != null)
                        Text(
                          sol['emailCliente'].toString(),
                          style: const TextStyle(color: Palette.kMuted, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Text(_estadoLabel,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Palette.kBorder),
            const SizedBox(height: 10),

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
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Palette.kField,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, size: 13, color: Palette.kMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Obs: ${sol['observaciones']}',
                        style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (sol['notaAdmin'] != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, size: 13, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Nota admin: ${sol['notaAdmin']}',
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
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
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    sol['comprobanteUrl'].toString(),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Palette.kField,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(child: Icon(Icons.broken_image_rounded, color: Palette.kMuted)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Toca para ampliar el comprobante',
                    style: const TextStyle(color: Palette.kMuted, fontSize: 10)),
              ),
            ],

            // ── Acciones (solo si pendiente) ─────────────────────
            if (esPendiente) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _notaCtrl,
                style: const TextStyle(color: Palette.kTitle, fontSize: 13),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Nota de rechazo (opcional)',
                  hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 12),
                  filled: true, fillColor: Palette.kField,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Palette.kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Palette.kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Palette.kAccent)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onRechazar(_notaCtrl.text),
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onAprobar,
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: const Text('Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Palette.kMuted),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Palette.kTitle, fontSize: 12, fontWeight: FontWeight.w600),
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
  final Color confirmColor;

  const _ConfirmDialog({
    required this.titulo,
    required this.mensaje,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(titulo, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 16)),
      content: Text(mensaje, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: Palette.kMuted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white, elevation: 0),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
