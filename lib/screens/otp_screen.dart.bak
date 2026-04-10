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
  late final List<FocusNode> _nodes = List.generate(widget.length, (_) => FocusNode());
  late final List<TextEditingController> _ctrs = List.generate(widget.length, (_) => TextEditingController());

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
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Palette.kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.shield_outlined, size: 18, color: Palette.kAccent),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Confirma tu identidad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.kTitle)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      widget.subtitle ?? 'Ingresa el código de ${widget.length} dígitos enviado a tu correo.',
                      style: const TextStyle(color: Palette.kMuted, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Palette.kBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Expira en:', style: TextStyle(color: Palette.kMuted, fontSize: 13)),
                          Text(
                            _fmt(_sessionLeft),
                            style: TextStyle(
                              color: _sessionLeft < 60 ? Colors.redAccent : Palette.kTitle,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── OTP boxes ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(widget.length, (i) => _OtpBox(
                  controller: _ctrs[i],
                  focusNode: _nodes[i],
                  onChanged: (v) => _onChanged(i, v),
                )),
              ),

              const SizedBox(height: 16),

              // ── Reenviar ──
              if (widget.canResend)
                Center(
                  child: TextButton.icon(
                    onPressed: (_remaining > 0 || _resending || _validating) ? null : _resend,
                    icon: Icon(Icons.refresh, size: 18, color: _remaining > 0 ? Palette.kMuted : Palette.kAccent),
                    label: Text(
                      _remaining > 0
                          ? 'Reenviar en ${_fmt(_remaining)}'
                          : (_resending ? 'Enviando...' : 'Reenviar código'),
                      style: TextStyle(color: _remaining > 0 ? Palette.kMuted : Palette.kAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

              const Spacer(),

              // ── Confirmar ──
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _validating ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.kAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Palette.kAccent.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _validating
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirmar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Palette.kTitle),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.kAccent, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
