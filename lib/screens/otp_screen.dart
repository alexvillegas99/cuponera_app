import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:enjoy/services/otp_service.dart';
import 'package:enjoy/ui/enjoy.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.length,
    required this.email,
    required this.otpService,
    this.title = 'Verificación',
    this.subtitle,
    this.canResend = true,
    this.resendSeconds = 45,
    this.sessionSeconds = 300,
    this.maxResends = 3,
  });

  final int length;
  final String email;
  final OtpService otpService;
  final String title;
  final String? subtitle;
  final bool canResend;
  final int resendSeconds;
  final int sessionSeconds;
  final int maxResends;

  @override
  State<OtpVerifyScreen> createState() => OtpVerifyScreenState();
}

class OtpVerifyScreenState extends State<OtpVerifyScreen> {
  late final List<FocusNode> _nodes =
      List.generate(widget.length, (_) => FocusNode());
  late final List<TextEditingController> _ctrs =
      List.generate(widget.length, (_) => TextEditingController());

  bool _validating = false;
  bool _resending = false;
  int _remaining = 0;
  int _sessionLeft = 0;
  int _resendCount = 0;

  Timer? _resendTimer;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    if (widget.canResend) _startResendCooldown();
    _startSessionCountdown();
    // rebuild on focus change para colorear boxes
    for (final n in _nodes) {
      n.addListener(() { if (mounted) setState(() {}); });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _sessionTimer?.cancel();
    for (final n in _nodes) n.dispose();
    for (final c in _ctrs) c.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _remaining = widget.resendSeconds);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 0) {
        _resendTimer?.cancel();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _startSessionCountdown() {
    setState(() => _sessionLeft = widget.sessionSeconds);
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (_sessionLeft <= 0) {
        _sessionTimer?.cancel();
        if (mounted) Navigator.pop(context, false);
      } else {
        setState(() => _sessionLeft--);
      }
    });
  }

  String get _code => _ctrs.map((c) => c.text).join();
  int get _filled => _ctrs.where((c) => c.text.isNotEmpty).length;

  String _fmt(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _confirm() async {
    if (_code.length != widget.length) {
      _snack('Ingresa los ${widget.length} dígitos');
      return;
    }
    setState(() => _validating = true);
    try {
      final ok = await widget.otpService.verifyOtp(widget.email, _code);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _resend() async {
    if (!widget.canResend || _remaining > 0 || _resending) return;
    if (_resendCount >= widget.maxResends) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _resending = true;
      _resendCount++;
    });
    try {
      await widget.otpService.sendOtp(widget.email);
      if (!mounted) return;
      _snack('Código reenviado ($_resendCount/${widget.maxResends})');
      _startResendCooldown();
      _startSessionCountdown();
      // limpiar boxes
      for (final c in _ctrs) c.clear();
      _nodes[0].requestFocus();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo reenviar: $e');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final sessionCritical = _sessionLeft < 60;
    final canConfirm = _filled == widget.length && !_validating;
    final canResendNow = _remaining == 0 && !_resending && !_validating;

    return EnjoyScaffold(
      appBar: EnjoyAppBar(title: widget.title),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // ── Hero: ícono + título centrado ─────────────────
          Column(
            children: [
              const SizedBox(height: 10),
              IconBox(
                Icons.mail_outline_rounded,
                accent: true,
                size: 74,
                radius: 24,
                iconSize: 30,
              ),
              const SizedBox(height: 22),
              Text(
                'Confirma tu identidad',
                textAlign: TextAlign.center,
                style: EnjoyTheme.heading(
                    size: 22, weight: FontWeight.w800, color: ec.text),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  widget.subtitle ??
                      'Ingresa el código de ${widget.length} dígitos enviado a tu correo.',
                  textAlign: TextAlign.center,
                  style: EnjoyTheme.body(
                      size: 14, color: ec.textSoft, height: 1.45),
                ),
              ),
              const SizedBox(height: 14),
              // Email pill
              Pill(widget.email,
                  variant: PillVariant.glass,
                  icon: Icons.alternate_email_rounded),
            ],
          ),

          const SizedBox(height: 30),

          // ── OTP boxes ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              widget.length,
              (i) => _OtpBox(
                controller: _ctrs[i],
                focusNode: _nodes[i],
                onChanged: (v) => _onChanged(i, v),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Progreso + timer ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_filled de ${widget.length} dígitos',
                style: EnjoyTheme.body(size: 12, color: ec.textMute),
              ),
              Pill(
                _fmt(_sessionLeft),
                variant: sessionCritical ? PillVariant.red : PillVariant.glass,
                icon: Icons.timer_outlined,
                dense: true,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Reenviar ──────────────────────────────────────
          if (widget.canResend)
            Center(
              child: _ResendChip(
                enabled: canResendNow,
                resending: _resending,
                label: _remaining > 0
                    ? 'Reenviar en ${_fmt(_remaining)}'
                    : (_resending ? 'Enviando...' : 'Reenviar código'),
                onTap: canResendNow ? _resend : null,
              ),
            ),

          const Spacer(),

          // ── Botón confirmar ───────────────────────────────
          EnjoyButton(
            label: 'Confirmar',
            icon: Icons.check_rounded,
            loading: _validating,
            onPressed: canConfirm ? _confirm : null,
          ),
        ],
      ),
    );
  }
}

// ── Chip de reenvío (glass/naranja según estado) ───────────────────────
class _ResendChip extends StatelessWidget {
  const _ResendChip({
    required this.enabled,
    required this.resending,
    required this.label,
    this.onTap,
  });

  final bool enabled;
  final bool resending;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final fg = enabled ? ec.orangeSoft : ec.textMute;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? ec.orange.withValues(alpha: 0.10) : ec.glassStrong,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: enabled ? ec.orange.withValues(alpha: 0.28) : ec.stroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (resending)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: ec.orangeSoft),
              )
            else
              Icon(Icons.refresh_rounded, size: 15, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: EnjoyTheme.body(
                  size: 13, weight: FontWeight.w600, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OTP Box ────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final filled = controller.text.isNotEmpty;
    final focused = focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 58,
      decoration: BoxDecoration(
        color: filled ? ec.orange.withValues(alpha: 0.08) : ec.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? ec.orange
              : filled
                  ? ec.orange.withValues(alpha: 0.45)
                  : ec.stroke,
          width: focused ? 2 : 1.2,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: ec.orange.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 1,
        textAlign: TextAlign.center,
        cursorColor: ec.orange,
        style: EnjoyTheme.heading(
          size: 22,
          weight: FontWeight.w800,
          color: filled ? ec.orangeSoft : ec.text,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
