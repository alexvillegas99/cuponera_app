import 'package:flutter/material.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:enjoy/services/solicitud_cuponera_service.dart';

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

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'APROBADO':
        return const Color(0xFF16A34A);
      case 'RECHAZADO':
        return const Color(0xFFDC2626);
      default:
        return Palette.kAccent;
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
        return 'Pendiente';
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
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        title: const Text('Mis solicitudes', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Palette.kAccent))
          : _solicitudes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No tienes solicitudes aún', style: TextStyle(color: Palette.kMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _solicitudes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final s = _solicitudes[i];
                      final estado = s['estado'] ?? 'PENDIENTE';
                      final color = _estadoColor(estado);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: cuponera + estado
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(_estadoIcon(estado), size: 18, color: color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['cuponeraNombre'] ?? 'Cuponera',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Palette.kTitle,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        _formatFecha(s['createdAt']),
                                        style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _estadoLabel(estado),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Detalles
                            Row(
                              children: [
                                _InfoChip(icon: Icons.attach_money, text: '\$${s['cuponeraPrecio'] ?? '0'}'),
                                const SizedBox(width: 8),
                                if (s['montoTransferido'] != null && s['montoTransferido'].toString().isNotEmpty)
                                  _InfoChip(icon: Icons.wallet, text: 'Transferido: \$${s['montoTransferido']}'),
                              ],
                            ),

                            // Nota admin
                            if (s['notaAdmin'] != null && s['notaAdmin'].toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: estado == 'RECHAZADO'
                                      ? const Color(0xFFFEF2F2)
                                      : Palette.kBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: estado == 'RECHAZADO' ? const Color(0xFFDC2626) : Palette.kMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        s['notaAdmin'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: estado == 'RECHAZADO' ? const Color(0xFFDC2626) : Palette.kMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Palette.kBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Palette.kMuted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: Palette.kTitle, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
