import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class QrResultScreen extends StatelessWidget {
  final Map<String, dynamic> qrData;
  const QrResultScreen({super.key, required this.qrData});

  // ── helpers ──────────────────────────────────────────────────
  bool get _valido => qrData['valido'] == true;

  String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('dd MMM yyyy', 'es').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  // ── registro ─────────────────────────────────────────────────
  Future<void> _registrar(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Palette.kAccent),
                ),
              ),
              SizedBox(width: 16),
              Text('Registrando canje…',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );

    try {
      final historicoService = HistoricoCuponService();
      final authService = AuthService();
      final usuario = await authService.getUser();

      final cuponId = qrData['_id'];
      final rol = usuario?['rol']?.toString().toLowerCase();
      final esStaff = rol == 'staff';
      final escaneadoPorId =
          qrData['_escaneadoPorId']?.toString() ??
          usuario?['_id']?.toString();
      final usuarioId = esStaff
          ? (usuario?['usuarioCreacion']?.toString())
          : usuario?['_id']?.toString();

      await historicoService.registrarEscaneo({
        'cupon': cuponId,
        'usuario': usuarioId,
        'escaneadoPor': escaneadoPorId,
      });

      if (!context.mounted) return;
      Navigator.of(context).pop(); // cierra loader

      // Construye el item localmente para evitar reconsultar todo el historial
      final newItem = <String, dynamic>{
        'cupon': {
          '_id': qrData['_id'],
          'secuencial': qrData['secuencial'],
          'estado': qrData['estado'],
          'version': qrData['version'],
          'fechaActivacion': qrData['fechaActivacion'],
          'fechaVencimiento': qrData['fechaVencimiento'],
        },
        'usuario': {
          '_id': usuarioId,
          'nombre': esStaff ? '—' : (usuario?['nombre'] ?? ''),
        },
        'escaneadoPor': {
          '_id': escaneadoPorId,
          'nombre': usuario?['nombre'] ?? '',
          'rol': rol,
        },
        'fechaEscaneo': DateTime.now().toUtc().toIso8601String(),
      };

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cupón registrado correctamente'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      context.pop(newItem);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // cierra loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final numero = qrData['secuencial']?.toString() ?? '—';
    final version = qrData['version']?['nombre']?.toString() ?? '—';
    final fechaInicio = _fmt(qrData['fechaActivacion']?.toString());
    final fechaFin = _fmt(qrData['fechaVencimiento']?.toString());
    final mensaje = qrData['message'] as String? ??
        (_valido ? 'Cupón válido para canjear' : 'Cupón no válido');

    final statusColor =
        _valido ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final statusBg =
        _valido ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);

    return Scaffold(
      backgroundColor: Palette.kBg,
      body: Column(
        children: [
          // ── Header con gradiente ──────────────────────────────
          _Header(valido: _valido, numero: numero, version: version),

          // ── Contenido scrollable ──────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  // Estado / mensaje
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _valido
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: statusColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mensaje,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Detalles
                  _DetailCard(children: [
                    _DetailRow(
                      icon: Icons.bookmark_outline_rounded,
                      label: 'Versión',
                      value: version,
                    ),
                    const _Divider(),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Activación',
                      value: fechaInicio,
                    ),
                    const _Divider(),
                    _DetailRow(
                      icon: Icons.event_rounded,
                      label: 'Vencimiento',
                      value: fechaFin,
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // ── Botones de acción ─────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _valido
                  ? SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _registrar(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 20),
                        label: const Text(
                          'Registrar canje',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Palette.kMuted,
                          side: BorderSide(
                              color: Palette.kBorder, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded,
                            size: 18),
                        label: const Text(
                          'Regresar',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  // Volver al inicio
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton.icon(
                      onPressed: () => context.go('/home'),
                      style: TextButton.styleFrom(
                        foregroundColor: Palette.kMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.home_rounded, size: 18),
                      label: const Text(
                        'Volver al inicio',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header(
      {required this.valido,
      required this.numero,
      required this.version});

  final bool valido;
  final String numero;
  final String version;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final List<Color> gradient = valido
        ? [Palette.kPrimary, const Color(0xFF1E3A5F)]
        : [const Color(0xFF374151), const Color(0xFF1F2937)];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.pop(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: Colors.white70),
                SizedBox(width: 4),
                Text('Volver',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Ícono circular
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1.5),
                ),
                child: Icon(
                  valido
                      ? Icons.qr_code_2_rounded
                      : Icons.qr_code_2_rounded,
                  size: 32,
                  color: valido ? Palette.kAccent : Colors.white38,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cupón #$numero',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      version,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Chip de estado
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: valido
                  ? Palette.kAccent.withOpacity(0.18)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: valido
                    ? Palette.kAccent.withOpacity(0.5)
                    : Colors.white.withOpacity(0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  valido ? Icons.verified_rounded : Icons.block_rounded,
                  size: 14,
                  color:
                      valido ? Palette.kAccent : Colors.white54,
                ),
                const SizedBox(width: 6),
                Text(
                  valido ? 'Válido' : 'No válido',
                  style: TextStyle(
                    color: valido ? Palette.kAccent : Colors.white54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de detalles ───────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Palette.kAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: Palette.kAccent),
          ),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              color: Palette.kMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Palette.kTitle,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Palette.kBorder);
  }
}
