// lib/screens/profile/edit_contact_with_otp_screen.dart  (solo la parte del widget OTP)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:enjoy/services/otp_service.dart';
import '../../../ui/palette.dart';
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    required this.length,
    required this.email,
    required this.otpService,
    this.title = 'Verificación',
    this.subtitle,
    this.canResend = true,
    this.resendSeconds = 45,
    this.sessionSeconds = 300, // ⏱️ 5 minutos
    this.maxResends = 3,       // ⏱️ máximo 3 reenvíos
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
  int _remaining = 0;       // cooldown de reenvío
  int _sessionLeft = 0;     // tiempo restante de sesión
  int _resendCount = 0;     // cuántos reenvíos van

  Timer? _resendTimer;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    if (widget.canResend) _startResendCooldown();
    _startSessionCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _sessionTimer?.cancel();
    for (final n in _nodes) n.dispose();
    for (final c in _ctrs) c.dispose();
    super.dispose();
  }

  // ---------------- TIMERS ----------------
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
        if (!mounted) return;
        Navigator.pop(context, false); // ⏹ expira sesión
      } else {
        setState(() => _sessionLeft--);
      }
    });
  }

  // ---------------- HELPERS ----------------
  String get _code => _ctrs.map((c) => c.text).join();

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

  // ---------------- ACTIONS ----------------
  Future<void> _confirm() async {
    if (_code.length != widget.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingresa los ${widget.length} dígitos')),
      );
      return;
    }

    if (mounted) setState(() => _validating = true);
    try {
      final ok = await widget.otpService.verifyOtp(widget.email, _code);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _resend() async {
    if (!widget.canResend || _remaining > 0 || _resending) return;
    if (_resendCount >= widget.maxResends) {
      Navigator.pop(context, false); // ⛔️ más de 3 reintentos
      return;
    }

    setState(() {
      _resending = true;
      _resendCount++;
    });

    try {
      await widget.otpService.sendOtp(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Código reenviado ($_resendCount/${widget.maxResends})')),
      );

      _startResendCooldown();
      _startSessionCountdown(); // 🔄 reinicia 5 minutos
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reenviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Palette.kAccent,
        foregroundColor: Palette.kBg,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Palette.kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Palette.kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confirma tu identidad',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Palette.kTitle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle ??
                          'Hemos enviado un código de ${widget.length} dígitos. Ingresa el código para continuar.',
                      style: const TextStyle(color: Palette.kMuted, height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('El código expira en:',
                            style: TextStyle(color: Palette.kSub)),
                        Text(
                          _fmt(_sessionLeft),
                          style: const TextStyle(
                            color: Palette.kTitle,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // OTP inputs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  widget.length,
                  (i) => _OtpBox(
                    controller: _ctrs[i],
                    focusNode: _nodes[i],
                    onChanged: (v) => _onChanged(i, v),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reenviar
              if (widget.canResend)
                TextButton.icon(
                  onPressed:
                      (_remaining > 0 || _resending || _validating) ? null : _resend,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    _remaining > 0
                        ? 'Reenviar en ${_fmt(_remaining)}'
                        : (_resending ? 'Enviando...' : 'Reenviar código'),
                  ),
                ),

              const Spacer(),

              // Confirmar
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _validating ? null : _confirm,
                  child: _validating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return SizedBox(
      width: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Palette.kTitle,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Palette.kField,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.kAccent, width: 1.6),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
