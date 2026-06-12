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
  final FocusNode _otpFocus = FocusNode();
  final TextEditingController _otpController = TextEditingController();

  bool _validating = false;
  bool _resending = false;
  bool _otpError = false;
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
    _otpFocus.addListener(_refreshOtpBoxes);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _sessionTimer?.cancel();
    _otpFocus
      ..removeListener(_refreshOtpBoxes)
      ..dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _refreshOtpBoxes() {
    if (mounted) setState(() {});
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

  String get _code => _otpController.text;
  int get _filled => _code.length;

  String _fmt(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onChanged(String value) {
    setState(() => _otpError = false);
    if (value.length == widget.length && !_validating) {
      unawaited(_confirm());
    }
  }

  void _focusOtpInput() {
    _otpFocus.requestFocus();
    _otpController.selection = TextSelection.collapsed(
      offset: _otpController.text.length,
    );
  }

  Future<void> _confirm() async {
    if (_validating) return;
    if (_code.length != widget.length) {
      _snack('Ingresa los ${widget.length} dígitos');
      return;
    }
    var success = false;
    var failed = false;
    setState(() {
      _validating = true;
      _otpError = false;
    });
    try {
      final ok = await widget.otpService.verifyOtp(widget.email, _code);
      if (!mounted) return;
      if (ok) {
        success = true;
        Navigator.pop(context, true);
        return;
      }
      failed = true;
      _snack('El código no es válido. Corrígelo e intenta nuevamente.');
    } catch (e) {
      if (!mounted) return;
      failed = true;
      _snack(e.toString());
    } finally {
      if (mounted && !success) {
        setState(() {
          _validating = false;
          _otpError = failed;
        });
        if (failed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focusOtpInput();
          });
        }
      }
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
      _otpController.clear();
      _otpError = false;
      _otpFocus.requestFocus();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      body: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
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
                            size: 22,
                            weight: FontWeight.w800,
                            color: ec.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            widget.subtitle ??
                                'Ingresa el código de ${widget.length} dígitos enviado a tu correo.',
                            textAlign: TextAlign.center,
                            style: EnjoyTheme.body(
                              size: 14,
                              color: ec.textSoft,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Email pill
                        Pill(
                          widget.email,
                          variant: PillVariant.glass,
                          icon: Icons.alternate_email_rounded,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ── OTP boxes ─────────────────────────────────────
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _focusOtpInput,
                      child: Stack(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(widget.length, (i) {
                              final digit = i < _code.length ? _code[i] : '';
                              final activeIndex = _filled >= widget.length
                                  ? widget.length - 1
                                  : _filled;
                              return _OtpBox(
                                digit: digit,
                                focused: _otpFocus.hasFocus && i == activeIndex,
                                error: _otpError,
                              );
                            }),
                          ),
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0,
                              child: TextField(
                                controller: _otpController,
                                focusNode: _otpFocus,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                enableInteractiveSelection: false,
                                showCursor: false,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(
                                    widget.length,
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                onTap: _focusOtpInput,
                                onChanged: _onChanged,
                                onSubmitted: (_) {
                                  if (_filled == widget.length) _confirm();
                                },
                              ),
                            ),
                          ),
                        ],
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
                          variant: sessionCritical
                              ? PillVariant.red
                              : PillVariant.glass,
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
                              : (_resending
                                    ? 'Enviando...'
                                    : 'Reenviar código'),
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
              ),
            ),
          ),
        ),
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
                  strokeWidth: 1.5,
                  color: ec.orangeSoft,
                ),
              )
            else
              Icon(Icons.refresh_rounded, size: 15, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: EnjoyTheme.body(
                size: 13,
                weight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OTP Box ────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final String digit;
  final bool focused;
  final bool error;

  const _OtpBox({
    required this.digit,
    required this.focused,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final filled = digit.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 58,
      decoration: BoxDecoration(
        color: filled ? ec.orange.withValues(alpha: 0.08) : ec.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error
              ? ec.red
              : focused
              ? ec.orange
              : filled
              ? ec.orange.withValues(alpha: 0.45)
              : ec.stroke,
          width: focused ? 2 : 1.2,
        ),
        boxShadow: error
            ? [
                BoxShadow(
                  color: ec.red.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : focused
            ? [
                BoxShadow(
                  color: ec.orange.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        child: Text(
          digit,
          key: ValueKey(digit),
          textAlign: TextAlign.center,
          style: EnjoyTheme.heading(
            size: 22,
            weight: FontWeight.w800,
            color: filled ? ec.orangeSoft : ec.text,
          ),
        ),
      ),
    );
  }
}
