import 'package:enjoy/widgets/branded_modal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:enjoy/services/registration_api.dart';
import 'package:enjoy/services/otp_service.dart';
import 'package:enjoy/screens/otp_screen.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:url_launcher/url_launcher.dart';

enum TipoIdentificacion { CEDULA, RUC, PASAPORTE }

class RegisterClienteScreen extends StatefulWidget {
  /// Datos pre-llenados cuando el usuario viene desde Google Sign-In.
  /// Contiene: nombres, apellidos, email, googleId (opcional).
  final Map<String, dynamic>? googleData;

  const RegisterClienteScreen({super.key, this.googleData});

  @override
  State<RegisterClienteScreen> createState() => _RegisterClienteScreenState();
}

class _RegisterClienteScreenState extends State<RegisterClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = RegistrationApi();
  final _otp = OtpService();

  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _identificacion = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _telefono = TextEditingController();

  TipoIdentificacion _tipo = TipoIdentificacion.CEDULA;
  bool _loading = false;
  bool _emailOk = false;
  bool _obscure = true;
  bool _aceptaTerminos = false;
  bool _fromGoogle = false;

  static const int _otpLen = 5;

  @override
  void initState() {
    super.initState();
    final g = widget.googleData;
    if (g != null) {
      _nombres.text = g['nombres'] ?? '';
      _apellidos.text = g['apellidos'] ?? '';
      _email.text = g['email'] ?? '';
      _fromGoogle = true;
      _emailOk = true; // Email verificado por Google, saltar OTP
    }
  }

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _identificacion.dispose();
    _email.dispose();
    _password.dispose();
    _telefono.dispose();
    super.dispose();
  }

  // ── Validaciones ──
  String? _reqMin2(String? v) =>
      (v == null || v.trim().length < 2) ? 'Requerido (mín. 2 caracteres)' : null;
  String? _reqNotEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;
  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requerido';
    final rx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return rx.hasMatch(v.trim()) ? null : 'Email inválido';
  }
  String? _pwdVal(String? v) =>
      (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null;

  // ── Paso 1: validar correo ──
  Future<void> _checkEmail() async {
    final err = _emailVal(_email.text);
    if (err != null) {
      _snack(err);
      return;
    }
    final correo = _email.text.trim();

    setState(() => _loading = true);
    try {
      final available = await _api.checkEmailAvailable(correo);
      if (!available) {
        await showBrandedDialog(context,
          title: 'Correo ya registrado',
          message: 'Usa otro correo o inicia sesión con ese email.',
          icon: Icons.warning_amber_rounded,
        );
        return;
      }
      setState(() => _emailOk = true);
      _snack('Correo disponible. Completa tus datos.');
    } catch (e) {
      await showBrandedDialog(context,
        title: 'Error al verificar',
        message: e.toString(),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Paso 2: OTP + crear cuenta ──
  Future<void> _submit() async {
    if (!_emailOk) {
      _snack('Primero valida tu correo.');
      return;
    }
    if (!_aceptaTerminos) {
      _snack('Debes aceptar los Términos y Condiciones.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final correo = _email.text.trim();

      // Si viene de Google, el email ya está verificado — saltar OTP
      if (!_fromGoogle) {
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
        if (ok != true) return;
      }

      final dto = {
        "nombres": _nombres.text.trim(),
        "apellidos": _apellidos.text.trim(),
        "tipoIdentificacion": _tipo.name,
        "identificacion": _identificacion.text.trim(),
        "email": correo,
        "password": _password.text,
        "telefono": _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
      };

      await _api.crearCliente(dto);
      if (!mounted) return;
      await showBrandedDialog(context,
        title: 'Cuenta creada',
        message: 'Tu cuenta ha sido registrada. Ahora puedes iniciar sesión.',
        icon: Icons.check_circle_outline,
      );
      context.pop();
    } catch (e) {
      await showBrandedDialog(context,
        title: 'No se pudo registrar',
        message: e.toString(),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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

  // ── Decoración de input ──
  InputDecoration _inputDec(String hint, {IconData? icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Palette.kMuted, size: 20) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: Palette.kBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.kAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Crear cuenta', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Step 1: Email ──
                  _SectionCard(
                    icon: Icons.mail_outline,
                    title: 'Correo electrónico',
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _email,
                            readOnly: _emailOk || _fromGoogle,
                            keyboardType: TextInputType.emailAddress,
                            cursorColor: Palette.kAccent,
                            style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                            decoration: _inputDec('email@ejemplo.com', icon: Icons.alternate_email),
                          ),
                        ),
                        if (!_fromGoogle) const SizedBox(width: 10),
                        if (!_fromGoogle) SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading || _emailOk ? null : _checkEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _emailOk ? Palette.kPrimary : Palette.kAccent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _emailOk
                                  ? Palette.kPrimary.withOpacity(0.8)
                                  : Palette.kAccent.withOpacity(0.5),
                              disabledForegroundColor: Colors.white70,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: _loading && !_emailOk
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_emailOk ? Icons.check : Icons.send, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        _emailOk ? 'Validado' : 'Verificar',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Step 2: Datos (bloqueado si no validó email) ──
                  IgnorePointer(
                    ignoring: !_emailOk,
                    child: AnimatedOpacity(
                      opacity: _emailOk ? 1 : 0.45,
                      duration: const Duration(milliseconds: 200),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Datos personales
                            _SectionCard(
                              icon: Icons.person_outline,
                              title: 'Datos personales',
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _nombres,
                                    validator: _reqMin2,
                                    cursorColor: Palette.kAccent,
                                    style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                                    decoration: _inputDec('Nombres', icon: Icons.badge_outlined),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _apellidos,
                                    validator: _reqMin2,
                                    cursorColor: Palette.kAccent,
                                    style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                                    decoration: _inputDec('Apellidos', icon: Icons.badge_outlined),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _telefono,
                                    keyboardType: TextInputType.phone,
                                    cursorColor: Palette.kAccent,
                                    style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                                    decoration: _inputDec('Teléfono (opcional)', icon: Icons.phone_outlined),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Identificación
                            _SectionCard(
                              icon: Icons.credit_card,
                              title: 'Identificación',
                              child: Column(
                                children: [
                                  DropdownButtonFormField<TipoIdentificacion>(
                                    value: _tipo,
                                    decoration: _inputDec('Tipo'),
                                    dropdownColor: Colors.white,
                                    items: TipoIdentificacion.values
                                        .map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t.name, style: const TextStyle(color: Palette.kTitle, fontSize: 14)),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => _tipo = v ?? TipoIdentificacion.CEDULA),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _identificacion,
                                    validator: _reqNotEmpty,
                                    cursorColor: Palette.kAccent,
                                    style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                                    decoration: _inputDec(
                                      _tipo == TipoIdentificacion.RUC ? 'RUC' : 'Cédula / Pasaporte',
                                      icon: Icons.fingerprint,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Contraseña
                            _SectionCard(
                              icon: Icons.lock_outline,
                              title: 'Contraseña',
                              child: TextFormField(
                                controller: _password,
                                validator: _pwdVal,
                                obscureText: _obscure,
                                cursorColor: Palette.kAccent,
                                style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                                decoration: _inputDec(
                                  'Mínimo 6 caracteres',
                                  icon: Icons.lock_outline,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: Palette.kMuted,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ── Términos y condiciones ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _aceptaTerminos,
                                    onChanged: (v) => setState(() => _aceptaTerminos = v ?? false),
                                    activeColor: Palette.kAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => launchUrl(
                                      Uri.parse('https://portal.ecuenjoy.com/privacy-policy'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    child: Text.rich(
                                      TextSpan(
                                        text: 'Acepto los ',
                                        style: const TextStyle(color: Palette.kMuted, fontSize: 13),
                                        children: [
                                          TextSpan(
                                            text: 'Términos y Condiciones',
                                            style: TextStyle(
                                              color: Palette.kAccent,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                              decorationColor: Palette.kAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // ── Botón submit ──
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: (_loading || !_emailOk || !_aceptaTerminos) ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Palette.kAccent,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Palette.kAccent.withOpacity(0.5),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: _loading
                                    ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.check, size: 18),
                                label: Text(
                                  _loading ? 'Creando…' : 'Crear cuenta',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
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

// ───────────── Section card reusable
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Palette.kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: Palette.kAccent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Palette.kTitle,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
