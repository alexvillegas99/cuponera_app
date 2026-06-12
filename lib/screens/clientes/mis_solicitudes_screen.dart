import 'package:enjoy/ui/enjoy.dart';
import 'package:enjoy/services/solicitud_cuponera_service.dart';
import 'package:flutter/material.dart';

class MisSolicitudesScreen extends StatefulWidget {
  final String clienteId;
  const MisSolicitudesScreen({super.key, required this.clienteId});

  @override
  State<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends State<MisSolicitudesScreen> {
  bool _loading = true;
  List<dynamic> _solicitudes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final data = await SolicitudCuponeraService.misSolicitudes(widget.clienteId);
    if (mounted) {
      setState(() {
        _solicitudes = data;
        _loading = false;
      });
    }
  }

  Color _estadoColor(EnjoyColors ec, String estado) {
    switch (estado) {
      case 'APROBADO':
        return ec.green;
      case 'RECHAZADO':
        return ec.red;
      default:
        return ec.orange;
    }
  }

  PillVariant _estadoPill(String estado) {
    switch (estado) {
      case 'APROBADO':
        return PillVariant.green;
      case 'RECHAZADO':
        return PillVariant.red;
      default:
        return PillVariant.orange;
    }
  }

  IconData _estadoIcon(String estado) {
    switch (estado) {
      case 'APROBADO':
        return Icons.check_circle;
      case 'RECHAZADO':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'APROBADO':
        return 'Aprobada';
      case 'RECHAZADO':
        return 'Rechazada';
      default:
        return 'En revisión';
    }
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return '';
    try {
      final d = DateTime.parse(fecha);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return fecha;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Mis Solicitudes'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ec.orange))
          : _solicitudes.isEmpty
              ? _emptyState(ec)
              : RefreshIndicator(
                  color: ec.orange,
                  backgroundColor: ec.glassStrong,
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    itemCount: _solicitudes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _card(ec, _solicitudes[i]),
                  ),
                ),
    );
  }

  Widget _emptyState(EnjoyColors ec) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: ec.glass,
              shape: BoxShape.circle,
              border: Border.all(color: ec.stroke),
            ),
            child: Icon(Icons.receipt_long, size: 38, color: ec.textMute),
          ),
          const SizedBox(height: 16),
          Text('No tienes solicitudes aún',
              style: EnjoyTheme.body(
                  weight: FontWeight.w600, color: ec.textSoft)),
        ],
      ),
    );
  }

  Widget _card(EnjoyColors ec, dynamic s) {
    final estado = (s['estado'] ?? 'PENDIENTE').toString();
    final color = _estadoColor(ec, estado);
    final aprobado = estado == 'APROBADO';
    final rechazado = estado == 'RECHAZADO';

    return GlassCard(
      leftAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ícono de membresía (acento si está aprobada/pendiente)
              IconBox(
                Icons.local_activity_rounded,
                accent: !rechazado,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['cuponeraNombre'] ?? 'Membresía',
                      style: EnjoyTheme.heading(size: 15, color: ec.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFecha(s['createdAt']),
                      style: EnjoyTheme.body(size: 12, color: ec.textMute),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Pill de estado
              Pill(
                _estadoLabel(estado),
                variant: _estadoPill(estado),
                icon: _estadoIcon(estado),
                dense: true,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Chips de detalle
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                  icon: Icons.attach_money,
                  text: '\$${s['cuponeraPrecio'] ?? '0'}'),
              if (s['montoTransferido'] != null &&
                  s['montoTransferido'].toString().isNotEmpty)
                _InfoChip(
                    icon: Icons.account_balance_wallet_outlined,
                    text: 'Transferido: \$${s['montoTransferido']}'),
              if (s['esRegalo'] == true)
                _InfoChip(
                  icon: Icons.card_giftcard_rounded,
                  text: () {
                    final para =
                        (s['destinatarioNombre']?.toString().trim().isNotEmpty ?? false)
                            ? '🎁 Para ${s['destinatarioNombre']}'
                            : '🎁 Regalo';
                    if (!aprobado) return para;
                    return s['regaloAbierto'] == true
                        ? '$para · Abierto'
                        : '$para · Sin abrir';
                  }(),
                ),
            ],
          ),

          // Nota admin
          if (s['notaAdmin'] != null && s['notaAdmin'].toString().isNotEmpty) ...[
            const EnjoyDivider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 15, color: rechazado ? ec.red : ec.textMute),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s['notaAdmin'],
                    style: EnjoyTheme.body(
                      size: 12.5,
                      height: 1.4,
                      color: rechazado
                          ? ec.red
                          : (aprobado ? ec.textSoft : ec.textSoft),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ec.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ec.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ec.orangeSoft),
          const SizedBox(width: 5),
          Text(text,
              style: EnjoyTheme.body(
                  size: 12, weight: FontWeight.w600, color: ec.text)),
        ],
      ),
    );
  }
}
