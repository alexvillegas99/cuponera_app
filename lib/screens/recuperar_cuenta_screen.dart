import 'package:enjoy/screens/otp_screen.dart';
import 'package:enjoy/widgets/branded_modal.dart';
import 'package:flutter/material.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/otp_service.dart';
// Usa TU widget OTP (según lo pusiste en el proyecto):
// Si tu OTP está en otra ruta, ajusta el import arriba.
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
  bool _showPass = false;
  bool _showPass2 = false;

  final _correoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Paso 2: contraseñas
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  RecoveryMode _mode = RecoveryMode.cliente;
  bool _loading = false;
  bool _otpOk = false; // <- cuando el OTP se valida, mostramos campos de clave

  // ===== Paleta (azul oscuro) =====
  static const Color _brand = Color(0xFF0D2B75);
  static const Color _brandAlt = Color(0xFF103896);
  static const Color _bg = Color(0xFFF6F9FF);
  static const Color _text = Color(0xFF0B1220);
  static const Color _sub = Color(0xFF6B7280);
  static const Color _surface = Colors.white;
  static const Color _field = Color(0xFFE9F0FF);
  static const Color _border = Color(0xFFE0E7FF);
  final _otpService = OtpService(); // Lee API_URL de .env
  static const int _otpLen = 5;

  Future<void> _dialog({required String title, required String message}) async {
  await showBrandedDialog(
    context,
    title: title,
    message: message,
    icon: Icons.info_outline,
  );
}

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
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Ingresa tu nueva contraseña';
    if (s.length < 6) return 'Usa al menos 6 caracteres';
    return null;
  }

  String? _pass2Val(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Repite tu nueva contraseña';
    if (s != _passCtrl.text.trim()) return 'Las contraseñas no coinciden';
    return null;
  }

  Future<void> _sendOtpAndValidate() async {
    if (!_formKey.currentState!.validate()) return;

    final correo = _correoCtrl.text.trim();
    setState(() => _loading = true);
    try {
      // 1) Enviar OTP dependiendo de modo
      await _otpService.sendOtp(correo);

      if (!mounted) return;

      // 2) Abrir tu pantalla OTP (la que nos pasaste)
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            length: _otpLen,
            email: correo,
            otpService: _otp,
            title: 'Verificación',
            subtitle:
                'Ingresa el código de $_otpLen dígitos enviado a $correo.',
            canResend: true,
            resendSeconds: 45,
            // sessionSeconds y maxResends si los usas en tu constructor.
          ),
        ),
      );

      if (!mounted) return;
      if (ok == true) {
        setState(() => _otpOk = true); // ✅ ahora mostramos los campos de clave
      }
    } catch (e) {
      _dialog(
        title: 'No pudimos enviar/verificar el código',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    // Validar solo los campos de password (no hace falta revalidar correo)
    if (!_otpOk) return;
    final passError = _passVal(_passCtrl.text);
    final pass2Error = _pass2Val(_pass2Ctrl.text);
    if (passError != null || pass2Error != null) {
      // Fuerza la visualización de errores usando un Form dedicado o SnackBar:
      if (passError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(passError)));
      } else if (pass2Error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(pass2Error)));
      }
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.resetPassword(
        email: _correoCtrl.text.trim(),
        newPassword: _passCtrl.text.trim(),
        isCliente: _mode == RecoveryMode.cliente,
      );
      if (!mounted) return;
      await _dialog(
        title: '¡Listo!',
        message: 'Tu contraseña fue actualizada.',
      );
      if (!mounted) return;
      Navigator.pop(context); // vuelve al login / pantalla anterior
    } catch (e) {
      _dialog(title: 'No pudimos actualizar', message: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }



  static InputDecoration _pillDec({
    required String hint,
    IconData? prefix,
    bool isPassword = false,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _sub),
    prefixIcon: prefix != null ? Icon(prefix, color: _sub) : null,
    filled: true,
    fillColor: _field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _brand, width: 1.2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _text,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 46,
                          width: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_brand, _brandAlt],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.key_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _otpOk
                                ? 'Define tu nueva contraseña'
                                : '¿Olvidaste tu contraseña?',
                            style: const TextStyle(
                              color: _text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _ModeChip(mode: _mode),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selector
                  AnimatedOpacity(
                    opacity: _otpOk ? 0.55 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring:
                          _otpOk, // 👈 bloquea taps cuando ya está en paso de contraseña
                      child: _Segmented(
                        active: _mode,
                        onChange: (m) => setState(() => _mode = m),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Paso 1: correo (antes de OTP)
                  if (!_otpOk) ...[
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Correo', style: TextStyle(color: _sub)),
                          const SizedBox(height: 8),
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: _field,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.alternate_email, color: _sub),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _correoCtrl,
                                    validator: _emailVal,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    style: const TextStyle(color: _text),
                                    onFieldSubmitted: (_) =>
                                        _sendOtpAndValidate(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _loading ? null : _sendOtpAndValidate,
                        icon: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                        label: Text(
                          _loading ? 'Enviando…' : 'Enviar código',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Te enviaremos un código para restablecer tu contraseña.',
                      style: TextStyle(color: _sub),
                    ),
                  ],

                  // Paso 2: contraseñas (después de OTP OK)
                  if (_otpOk) ...[
                    const Text(
                      'Nueva contraseña',
                      style: TextStyle(color: _sub),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passCtrl,
                      obscureText: !_showPass,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration:
                          _pillDec(
                            hint: 'Escribe tu nueva contraseña',
                            prefix: Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _showPass = !_showPass),
                              icon: Icon(
                                _showPass
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: _sub,
                              ),
                              tooltip: _showPass ? 'Ocultar' : 'Mostrar',
                            ),
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Repite tu contraseña',
                      style: TextStyle(color: _sub),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pass2Ctrl,
                      obscureText: !_showPass2,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration:
                          _pillDec(
                            hint: 'Repite tu nueva contraseña',
                            prefix: Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _showPass2 = !_showPass2),
                              icon: Icon(
                                _showPass2
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: _sub,
                              ),
                              tooltip: _showPass2 ? 'Ocultar' : 'Mostrar',
                            ),
                          ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _loading ? null : _resetPassword,
                        icon: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, color: Colors.white),
                        label: Text(
                          _loading ? 'Actualizando…' : 'Actualizar contraseña',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode});
  final RecoveryMode mode;

  @override
  Widget build(BuildContext context) {
    final txt = mode == RecoveryMode.cliente ? 'Cliente' : 'Empresa';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.kPrimary.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Palette.kPrimary.withOpacity(.25)),
      ),
      child: Text(
        txt,
        style: const TextStyle(
          color: Palette.kPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.active, required this.onChange});
  final RecoveryMode active;
  final ValueChanged<RecoveryMode> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Palette.kBorder),
      ),
      child: Row(
        children: [
          _SegItem(
            icon: Icons.person_outline,
            text: 'Cliente',
            selected: active == RecoveryMode.cliente,
            onTap: () => onChange(RecoveryMode.cliente),
          ),
          _SegItem(
            icon: Icons.business_outlined,
            text: 'Empresa',
            selected: active == RecoveryMode.empresa,
            onTap: () => onChange(RecoveryMode.empresa),
          ),
        ],
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  const _SegItem({
    required this.icon,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Palette.kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : Palette.kPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : Palette.kPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
}
