import 'package:enjoy/widgets/branded_modal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:enjoy/services/registration_api.dart';
import 'package:enjoy/services/otp_service.dart';
import 'package:enjoy/screens/otp_screen.dart';
import 'package:enjoy/widgets/pill_field.dart';
import 'package:enjoy/ui/palette.dart';

enum TipoIdentificacion { CEDULA, RUC, PASAPORTE }

class RegisterClienteScreen extends StatefulWidget {
  const RegisterClienteScreen({super.key});
  @override
  State<RegisterClienteScreen> createState() => _RegisterClienteScreenState();
}

class _RegisterClienteScreenState extends State<RegisterClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = RegistrationApi();
  final _otp = OtpService();

  // Controllers
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _identificacion = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _telefono = TextEditingController();

  DateTime? _fechaNac;
  TipoIdentificacion _tipo = TipoIdentificacion.CEDULA;

  bool _loading = false;
  bool _emailOk = false; // ← se vuelve true cuando el correo está disponible
  bool _obscure = true;

  static const int _otpLen = 5;

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



  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _fechaNac = picked);
  }

  // ---------- Validaciones ----------
  String? _reqMin2(String? v) =>
      (v == null || v.trim().length < 2) ? 'Requerido (mín. 2 caracteres)' : null;
  String? _reqNotEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;
  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requerido';
    final rx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return rx.hasMatch(v.trim()) ? null : 'Email inválido';
  }
  String? _pwdVal(String? v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null;

  // ---------- Paso 1: validar correo (sin OTP aún) ----------
  Future<void> _checkEmail() async {
    final err = _emailVal(_email.text);
    if (err != null) {
      await showBrandedDialog(
        context,
        title: 'Dato requerido',
        message: err,
        icon: Icons.error_outline,
      );
      return;
    }
    final correo = _email.text.trim();

    setState(() => _loading = true);
    try {
      final available = await _api.checkEmailAvailable(correo);
      if (!available) {
        await showBrandedDialog(
          context,
          title: 'Correo ya registrado',
          message: 'Usa otro correo o inicia sesión con ese email.',
          icon: Icons.warning_amber_rounded,
        );
        return;
      }
      setState(() => _emailOk = true);
      await showBrandedDialog(
        context,
        title: 'Correo válido',
        message: 'Perfecto, ahora completa tus datos.',
        icon: Icons.check_circle_outline,
      );
    } catch (e) {
      await showBrandedDialog(
        context,
        title: 'No pudimos verificar tu correo',
        message: e.toString(),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Paso 2: OTP al final + crear cuenta ----------
  Future<void> _submit() async {
    if (!_emailOk) {
      await showBrandedDialog(
        context,
        title: 'Verifica tu correo',
        message: 'Primero valida que tu correo esté disponible.',
        icon: Icons.mail_outline,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // 2.1 Enviar OTP ahora (al final del flujo)
      final correo = _email.text.trim();
      await _otp.sendOtp(correo);

      // 2.2 Verificar OTP
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

      // 2.3 Crear cuenta
      final dto = {
        "nombres": _nombres.text.trim(),
        "apellidos": _apellidos.text.trim(),
        "tipoIdentificacion": _tipo.name,
        "identificacion": _identificacion.text.trim(),
        "email": correo,
        "password": _password.text, // hash en backend
        "telefono": _telefono.text.trim().isEmpty ? null : _telefono.text.trim()
      };

      await _api.crearCliente(dto);
      if (!mounted) return;
      await showBrandedDialog(
        context,
        title: 'Cuenta creada',
        message: 'Tu cuenta ha sido registrada. Ahora puedes iniciar sesión.',
        icon: Icons.check_circle_outline,
      );
      context.pop();
    } catch (e) {
      await showBrandedDialog(
        context,
        title: 'No se pudo registrar',
        message: e.toString(),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kBg,
        elevation: 0,
        foregroundColor: Palette.kTitle,
        title: const Text('Registro'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Palette.kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Palette.kBorder),
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
                              colors: [Palette.kPrimary, Palette.kAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.person_add_alt_1, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _emailOk ? 'Completa tus datos' : 'Crea tu cuenta',
                            style: const TextStyle(
                              color: Palette.kTitle,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_emailOk)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Palette.kPrimary.withOpacity(.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Palette.kPrimary.withOpacity(.25)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified, size: 16, color: Palette.kPrimary),
                                SizedBox(width: 6),
                                Text('Correo validado', style: TextStyle(color: Palette.kPrimary, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Paso 1: Email + botón "Verificar"
                  const Text('Correo', style: TextStyle(color: Palette.kSub)),
                  const SizedBox(height: 8),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Palette.kField,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Palette.kBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.alternate_email, color: Palette.kSub),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _email,
                            readOnly: _emailOk,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                              hintText: 'email@ejemplo.com',
                              hintStyle: TextStyle(color: Palette.kMuted),
                            ),
                            style: const TextStyle(color: Palette.kTitle),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _emailOk ? Colors.transparent : Palette.kPrimary,
                            foregroundColor: _emailOk ? Palette.kPrimary : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: _emailOk ? Palette.kPrimary : Colors.transparent),
                            ),
                          ),
                          onPressed: _loading ? null : (_emailOk ? null : _checkEmail),
                          child: _loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_emailOk ? 'Validado' : 'Verificar', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Form siempre visible pero bloqueado hasta validar correo
                  Stack(
                    children: [
                      // Capa interactiva (se bloquea con IgnorePointer)
                      IgnorePointer(
                        ignoring: !_emailOk,
                        child: AnimatedOpacity(
                          opacity: _emailOk ? 1 : 0.55,
                          duration: const Duration(milliseconds: 180),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Nombres / Apellidos
                                const Text('Nombres', style: TextStyle(color: Palette.kSub)),
                                const SizedBox(height: 8),
                                PillField(hint: 'Tus nombres', controller: _nombres, icon: Icons.badge_outlined, validator: _reqMin2),
                                const SizedBox(height: 16),

                                const Text('Apellidos', style: TextStyle(color: Palette.kSub)),
                                const SizedBox(height: 8),
                                PillField(hint: 'Tus apellidos', controller: _apellidos, icon: Icons.badge_outlined, validator: _reqMin2),
                                const SizedBox(height: 16),

                                // Tipo + Identificación
                                const Text('Tipo de identificación', style: TextStyle(color: Palette.kSub)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Palette.kField,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: Palette.kBorder),
                                  ),
                                  child: DropdownButtonFormField<TipoIdentificacion>(
                                    value: _tipo,
                                    elevation: 0,
                                    decoration: const InputDecoration(border: InputBorder.none),
                                    items: TipoIdentificacion.values
                                        .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                                        .toList(),
                                    onChanged: (v) => setState(() => _tipo = v ?? TipoIdentificacion.CEDULA),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                const Text('Identificación', style: TextStyle(color: Palette.kSub)),
                                const SizedBox(height: 8),
                                PillField(
                                  hint: _tipo == TipoIdentificacion.RUC ? 'RUC' : 'Cédula / Pasaporte',
                                  controller: _identificacion,
                                  icon: Icons.credit_card,
                                  keyboardType: TextInputType.text,
                                  validator: _reqNotEmpty,
                                ),
                                const SizedBox(height: 16),

                                // Password
                                const Text('Contraseña', style: TextStyle(color: Palette.kSub)),
                                const SizedBox(height: 8),
                                PillField(
                                  hint: 'Mínimo 6 caracteres',
                                  controller: _password,
                                  icon: Icons.lock_outline,
                                  obscure: _obscure,
                                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                                  validator: _pwdVal,
                                ),
                                const SizedBox(height: 16),

                                // Teléfono / Dirección / Fecha (opcionales)
                                const Text('Teléfono', style: TextStyle(color: Palette.kSub)),
                                const SizedBox(height: 8),
                                PillField(
                                  hint: '099...',
                                  controller: _telefono,
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),

                               
                               

                              

                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Palette.kPrimary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: (_loading || !_emailOk) ? null : _submit,
                                    icon: _loading
                                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.check, color: Colors.white),
                                    label: Text(
                                      _loading ? 'Creando…' : 'Crear cuenta',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Candado/overlay (solo si está bloqueado)
                     /*  if (!_emailOk)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.only(top: 8, right: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Palette.kPrimary.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Palette.kPrimary.withOpacity(.25)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline, size: 16, color: Palette.kPrimary),
                                    SizedBox(width: 6),
                                    Text('Bloqueado', style: TextStyle(color: Palette.kPrimary, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ), */
                    ],
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
