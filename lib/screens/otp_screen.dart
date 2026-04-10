import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:enjoy/services/otp_service.dart';
import '../ui/palette.dart';

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
    final sessionCritical = _sessionLeft < 60;
    final canConfirm = _filled == widget.length && !_validating;
    final canResendNow = _remaining == 0 && !_resending && !_validating;

    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Palette.kPrimary,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Palette.kTitle,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Palette.kSurface,
            border: Border(
              bottom: BorderSide(color: Palette.kBorder, width: 1),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Header card ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Palette.kSurface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícono + título
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Palette.kAccent, Palette.kAccentLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Palette.kAccent.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Confirma tu identidad',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Palette.kTitle,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Subtítulo
                    Text(
                      widget.subtitle ??
                          'Ingresa el código de ${widget.length} dígitos enviado a tu correo.',
                      style: const TextStyle(
                        color: Palette.kMuted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Email pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Palette.kPrimary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Palette.kPrimary.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.alternate_email_rounded,
                              color: Palette.kPrimary, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            widget.email,
                            style: const TextStyle(
                              color: Palette.kPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

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
                  // Progreso
                  Text(
                    '$_filled de ${widget.length} dígitos',
                    style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                  ),
                  // Timer pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sessionCritical
                          ? Colors.redAccent.withOpacity(0.08)
                          : Palette.kField,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sessionCritical
                            ? Colors.redAccent.withOpacity(0.25)
                            : Palette.kBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: sessionCritical
                              ? Colors.redAccent
                              : Palette.kMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _fmt(_sessionLeft),
                          style: TextStyle(
                            color: sessionCritical
                                ? Colors.redAccent
                                : Palette.kTitle,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Reenviar ──────────────────────────────────────
              if (widget.canResend)
                Center(
                  child: GestureDetector(
                    onTap: canResendNow ? _resend : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: canResendNow
                            ? Palette.kAccent.withOpacity(0.08)
                            : Palette.kField,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: canResendNow
                              ? Palette.kAccent.withOpacity(0.25)
                              : Palette.kBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_resending)
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Palette.kAccent,
                              ),
                            )
                          else
                            Icon(
                              Icons.refresh_rounded,
                              size: 15,
                              color: canResendNow
                                  ? Palette.kAccent
                                  : Palette.kMuted,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            _remaining > 0
                                ? 'Reenviar en ${_fmt(_remaining)}'
                                : (_resending
                                    ? 'Enviando...'
                                    : 'Reenviar código'),
                            style: TextStyle(
                              color: canResendNow
                                  ? Palette.kAccent
                                  : Palette.kMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const Spacer(),

              // ── Botón confirmar ───────────────────────────────
              GestureDetector(
                onTap: canConfirm ? _confirm : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: canConfirm
                        ? const LinearGradient(
                            colors: [Palette.kAccent, Palette.kAccentLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: canConfirm ? null : Palette.kBorder,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: canConfirm
                        ? [
                            BoxShadow(
                              color: Palette.kAccent.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: _validating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              color: canConfirm ? Colors.white : Palette.kMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Confirmar',
                              style: TextStyle(
                                color: canConfirm
                                    ? Colors.white
                                    : Palette.kMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
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
    final filled = controller.text.isNotEmpty;
    final focused = focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 54,
      height: 58,
      decoration: BoxDecoration(
        color: filled
            ? Palette.kAccent.withOpacity(0.06)
            : Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? Palette.kAccent
              : filled
                  ? Palette.kAccent.withOpacity(0.35)
                  : Palette.kBorder,
          width: focused ? 2 : 1.2,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: Palette.kAccent.withOpacity(0.15),
                  blurRadius: 8,
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
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: filled ? Palette.kAccent : Palette.kTitle,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
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
