import 'package:enjoy/screens/otp_screen.dart';
import 'package:enjoy/widgets/branded_modal.dart';
import 'package:flutter/material.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/otp_service.dart';
import 'package:enjoy/ui/palette.dart';

enum RecoveryMode { cliente, empresa }

class RecuperarCuentaScreen extends StatefulWidget {
  const RecuperarCuentaScreen({super.key});

  @override
  State<RecuperarCuentaScreen> createState() => _RecuperarCuentaScreenState();
}

class _RecuperarCuentaScreenState extends State<RecuperarCuentaScreen> {
  final _auth = AuthService();
  final _otp = OtpService();

  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  RecoveryMode _mode = RecoveryMode.cliente;
  bool _loading = false;
  bool _otpOk = false;
  bool _showPass = false;
  bool _showPass2 = false;

  static const int _otpLen = 5;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
    final rx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return rx.hasMatch(v.trim()) ? null : 'Correo inválido';
  }

  String? _passVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu nueva contraseña';
    if (v.trim().length < 6) return 'Usa al menos 6 caracteres';
    return null;
  }

  String? _pass2Val(String? v) {
    if (v == null || v.trim().isEmpty) return 'Repite tu nueva contraseña';
    if (v != _passCtrl.text.trim()) return 'Las contraseñas no coinciden';
    return null;
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

  InputDecoration _inputDec(String hint, {IconData? icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Palette.kMuted, size: 20) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: Palette.kBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    );
  }

  Future<void> _sendOtpAndValidate() async {
    if (!_formKey.currentState!.validate()) return;

    final correo = _correoCtrl.text.trim();
    setState(() => _loading = true);
    try {
      await _otp.sendOtp(correo);
      if (!mounted) return;

      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            length: _otpLen,
            email: correo,
            otpService: _otp,
            title: 'Verificación',
            subtitle: 'Ingresa el código de $_otpLen dígitos enviado a $correo.',
            canResend: true,
            resendSeconds: 45,
          ),
        ),
      );

      if (!mounted) return;
      if (ok == true) setState(() => _otpOk = true);
    } catch (e) {
      await showBrandedDialog(context,
        title: 'Error',
        message: e.toString(),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_otpOk) return;
    final passError = _passVal(_passCtrl.text);
    final pass2Error = _pass2Val(_pass2Ctrl.text);
    if (passError != null) { _snack(passError); return; }
    if (pass2Error != null) { _snack(pass2Error); return; }

    setState(() => _loading = true);
    try {
      await _auth.resetPassword(
        email: _correoCtrl.text.trim(),
        newPassword: _passCtrl.text.trim(),
        isCliente: _mode == RecoveryMode.cliente,
      );
      if (!mounted) return;
      await showBrandedDialog(context,
        title: '¡Listo!',
        message: 'Tu contraseña fue actualizada.',
        icon: Icons.check_circle_outline,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      await showBrandedDialog(context,
        title: 'No pudimos actualizar',
        message: e.toString(),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Recuperar contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Paso 1: Email ──
                  if (!_otpOk)
                    _Card(
                      icon: Icons.mail_outline,
                      title: 'Ingresa tu correo',
                      subtitle: 'Te enviaremos un código para verificar tu identidad.',
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _correoCtrl,
                              validator: _emailVal,
                              keyboardType: TextInputType.emailAddress,
                              cursorColor: Palette.kAccent,
                              style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                              decoration: _inputDec('email@ejemplo.com', icon: Icons.alternate_email),
                              onFieldSubmitted: (_) => _sendOtpAndValidate(),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _loading ? null : _sendOtpAndValidate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Palette.kAccent,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Palette.kAccent.withOpacity(0.5),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: _loading
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.send, size: 18),
                                label: Text(_loading ? 'Enviando…' : 'Enviar código', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Acceso empresa (discreto) ──
                  if (!_otpOk) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => setState(() => _mode = _mode == RecoveryMode.cliente
                          ? RecoveryMode.empresa
                          : RecoveryMode.cliente),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business_outlined, size: 13, color: Palette.kMuted.withOpacity(0.6)),
                          const SizedBox(width: 5),
                          Text(
                            _mode == RecoveryMode.empresa
                                ? 'Volver a acceso cliente'
                                : 'Recuperar contraseña empresas',
                            style: TextStyle(
                              color: Palette.kMuted.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Paso 2: Nueva contraseña ──
                  if (_otpOk)
                    _Card(
                      icon: Icons.lock_outline,
                      title: 'Nueva contraseña',
                      subtitle: 'Ingresa y confirma tu nueva contraseña.',
                      child: Column(
                        children: [
                          TextField(
                            controller: _passCtrl,
                            obscureText: !_showPass,
                            cursorColor: Palette.kAccent,
                            style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                            decoration: _inputDec('Nueva contraseña', icon: Icons.lock_outline, suffix: IconButton(
                              icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Palette.kMuted, size: 20),
                              onPressed: () => setState(() => _showPass = !_showPass),
                            )),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pass2Ctrl,
                            obscureText: !_showPass2,
                            cursorColor: Palette.kAccent,
                            style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                            decoration: _inputDec('Repetir contraseña', icon: Icons.lock_outline, suffix: IconButton(
                              icon: Icon(_showPass2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Palette.kMuted, size: 20),
                              onPressed: () => setState(() => _showPass2 = !_showPass2),
                            )),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Palette.kAccent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Palette.kAccent.withOpacity(0.5),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: _loading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check, size: 18),
                              label: Text(_loading ? 'Actualizando…' : 'Actualizar contraseña', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────── Card section
class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _Card({required this.icon, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Palette.kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: Palette.kAccent),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(color: Palette.kTitle, fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

