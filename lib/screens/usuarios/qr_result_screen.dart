import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:enjoy/ui/enjoy.dart';
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
    final ec = context.ec;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(ec.orange),
                ),
              ),
              const SizedBox(width: 16),
              Text('Registrando canje…',
                  style: EnjoyTheme.body(
                      size: 14, weight: FontWeight.w600, color: ec.text)),
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
        SnackBar(
          content: const Text('Cupón registrado correctamente'),
          backgroundColor: context.ec.green,
        ),
      );
      context.pop(newItem);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // cierra loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: context.ec.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final numero = qrData['secuencial']?.toString() ?? '—';
    final version = qrData['version']?['nombre']?.toString() ?? '—';
    final fechaInicio = _fmt(qrData['fechaActivacion']?.toString());
    final fechaFin = _fmt(qrData['fechaVencimiento']?.toString());
    final estado = qrData['estado']?.toString() ?? '—';
    final mensaje = qrData['message'] as String? ??
        (_valido ? 'Cupón válido para canjear' : 'Cupón no válido');

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: EnjoyAppBar(
        title: 'Cupón #$numero',
        onBack: () => context.pop(),
      ),
      body: Column(
        children: [
          // ── Contenido scrollable ──────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
              child: Column(
                children: [
                  // Ícono grande con pop + pill de estado
                  RiseIn(
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        _PopIcon(valido: _valido),
                        const SizedBox(height: 14),
                        Pill(
                          _valido ? 'Válido' : 'No válido',
                          variant: _valido ? PillVariant.green : PillVariant.red,
                          dot: _valido,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          mensaje,
                          textAlign: TextAlign.center,
                          style: EnjoyTheme.heading(size: 20, color: ec.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Detalles
                  RiseIn(
                    delayMs: 80,
                    child: GlassCard(
                      child: Column(
                        children: [
                          _DetailRow(label: 'Versión', value: version),
                          const _Gap(),
                          _DetailRow(label: 'Activación', value: fechaInicio),
                          const _Gap(),
                          _DetailRow(label: 'Vencimiento', value: fechaFin),
                          const _Gap(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Estado',
                                  style: EnjoyTheme.body(
                                      size: 13, color: ec.textMute)),
                              Pill(
                                _capitalize(estado),
                                variant: _valido
                                    ? PillVariant.green
                                    : PillVariant.glass,
                                dense: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Botones de acción ─────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_valido)
                    EnjoyButton(
                      label: 'Registrar canje',
                      icon: Icons.check_circle_outline_rounded,
                      variant: EnjoyButtonVariant.green,
                      onPressed: () => _registrar(context),
                    )
                  else
                    EnjoyButton(
                      label: 'Regresar',
                      icon: Icons.arrow_back_rounded,
                      variant: EnjoyButtonVariant.ghost,
                      onPressed: () => context.pop(),
                    ),
                  const SizedBox(height: 10),
                  EnjoyButton(
                    label: 'Volver al inicio',
                    icon: Icons.home_rounded,
                    variant: EnjoyButtonVariant.ghost,
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Ícono circular grande con animación pop ───────────────────────
class _PopIcon extends StatefulWidget {
  const _PopIcon({required this.valido});
  final bool valido;

  @override
  State<_PopIcon> createState() => _PopIconState();
}

class _PopIconState extends State<_PopIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _c,
    curve: Curves.elasticOut,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final color = widget.valido ? ec.green : ec.red;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Icon(
          widget.valido
              ? Icons.check_rounded
              : Icons.close_rounded,
          color: color,
          size: 40,
        ),
      ),
    );
  }
}

// ── Fila de detalle ───────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Row(
      children: [
        Text(label, style: EnjoyTheme.body(size: 13, color: ec.textMute)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: EnjoyTheme.heading(size: 13, color: ec.text),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) => const EnjoyDivider(height: 22);
}
