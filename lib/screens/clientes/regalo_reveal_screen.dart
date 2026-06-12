// lib/screens/clientes/regalo_reveal_screen.dart
import 'package:enjoy/ui/enjoy.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:flutter/material.dart';

/// Pantalla para "abrir" un regalo recibido. Estado cerrado (caja + lazo +
/// botón) → al abrir llama al backend y revela la cuponera con el mensaje.
class RegaloRevealScreen extends StatefulWidget {
  final String cuponId;
  final String clienteId;
  final String cuponeraNombre;
  final String? regaloDe;
  final String? regaloMensaje;

  const RegaloRevealScreen({
    super.key,
    required this.cuponId,
    required this.clienteId,
    required this.cuponeraNombre,
    this.regaloDe,
    this.regaloMensaje,
  });

  @override
  State<RegaloRevealScreen> createState() => _RegaloRevealScreenState();
}

class _RegaloRevealScreenState extends State<RegaloRevealScreen>
    with SingleTickerProviderStateMixin {
  final _service = CuponesService();
  late final AnimationController _ctrl;
  bool _abierto = false;
  bool _abriendo = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    setState(() => _abriendo = true);
    final ok = await _service.abrirRegalo(widget.cuponId, widget.clienteId);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _abriendo = false;
        _abierto = true;
      });
      _ctrl.forward(from: 0);
    } else {
      setState(() => _abriendo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el regalo. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Tu regalo'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _abierto ? _buildAbierto(ec) : _buildCerrado(ec),
            ),
          ],
        ),
      ),
    );
  }

  // ── Estado cerrado ──────────────────────────────────────────────────
  Widget _buildCerrado(EnjoyColors ec) {
    return Column(
      key: const ValueKey('cerrado'),
      children: [
        Text(
          widget.regaloDe != null && widget.regaloDe!.trim().isNotEmpty
              ? 'Tienes un regalo de\n${widget.regaloDe}'
              : 'Tienes un regalo',
          textAlign: TextAlign.center,
          style: EnjoyTheme.heading(size: 22, weight: FontWeight.w800, color: ec.text),
        ),
        const SizedBox(height: 8),
        Text(
          'Toca la caja para descubrir tu cuponera',
          textAlign: TextAlign.center,
          style: EnjoyTheme.body(size: 14, color: ec.textMute),
        ),
        const SizedBox(height: 36),
        GestureDetector(
          onTap: _abriendo ? null : _abrir,
          child: _GiftBox(ec: ec, loading: _abriendo),
        ),
        const SizedBox(height: 40),
        EnjoyButton(
          label: _abriendo ? 'Abriendo…' : 'Abrir mi regalo',
          icon: Icons.card_giftcard_rounded,
          loading: _abriendo,
          onPressed: _abriendo ? null : _abrir,
        ),
      ],
    );
  }

  // ── Estado abierto (revelado) ───────────────────────────────────────
  Widget _buildAbierto(EnjoyColors ec) {
    return Column(
      key: const ValueKey('abierto'),
      children: [
        ScaleTransition(
          scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: ec.accentGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ec.orange.withValues(alpha: 0.5),
                  blurRadius: 40,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Icon(Icons.check_rounded, color: ec.onAccent, size: 52),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '¡Sorpresa! 🎉',
          textAlign: TextAlign.center,
          style: EnjoyTheme.heading(size: 24, weight: FontWeight.w800, color: ec.text),
        ),
        const SizedBox(height: 6),
        Text(
          widget.regaloDe != null && widget.regaloDe!.trim().isNotEmpty
              ? '${widget.regaloDe} te regaló'
              : 'Te regalaron',
          textAlign: TextAlign.center,
          style: EnjoyTheme.body(size: 14, color: ec.textMute),
        ),
        const SizedBox(height: 18),
        GlassCard(
          accent: true,
          child: Row(
            children: [
              const IconBox(Icons.local_activity_rounded, accent: true, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.cuponeraNombre,
                  style: EnjoyTheme.heading(size: 18, weight: FontWeight.w800, color: ec.text),
                ),
              ),
            ],
          ),
        ),
        if (widget.regaloMensaje != null &&
            widget.regaloMensaje!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_quote_rounded, size: 18, color: ec.orangeSoft),
                    const SizedBox(width: 6),
                    Text(
                      'Mensaje',
                      style: EnjoyTheme.body(size: 12, weight: FontWeight.w700, color: ec.orangeSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.regaloMensaje!,
                  style: EnjoyTheme.body(size: 15, height: 1.5, color: ec.text),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        EnjoyButton(
          label: 'Ver mi cuponera',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

/// Caja de regalo con lazo (estado cerrado).
class _GiftBox extends StatelessWidget {
  const _GiftBox({required this.ec, this.loading = false});
  final EnjoyColors ec;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        gradient: ec.accentGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: ec.orange.withValues(alpha: 0.5),
            blurRadius: 50,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Lazo vertical
          Container(width: 26, color: ec.onAccent.withValues(alpha: 0.30)),
          // Lazo horizontal
          Container(height: 26, color: ec.onAccent.withValues(alpha: 0.30)),
          // Nudo / ícono central
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ec.onAccent.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              color: ec.onAccent,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}
