// lib/screens/profile/edit_contact_with_otp_screen.dart
import 'dart:async';
import 'package:enjoy/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/otp_service.dart';
import '../../../ui/palette.dart';

/// ---------------------------------------------------------------------------
/// EDIT CONTACT + OTP (usa el widget _OtpVerifyScreen de este mismo archivo)
/// ---------------------------------------------------------------------------

class EditContactWithOtpScreen extends StatefulWidget {
  const EditContactWithOtpScreen({super.key});

  @override
  State<EditContactWithOtpScreen> createState() =>
      _EditContactWithOtpScreenState();
}

class _EditContactWithOtpScreenState extends State<EditContactWithOtpScreen> {
  final _auth = AuthService();
  final _otpService = OtpService(); // Lee API_URL de .env

  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  

  bool _locked = true;
  bool _saving = false;  // loading al guardar datos finales
  bool _sendingOtp = false;   // 🔹 loading al enviar OTP

  static const _otpLen = 5;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void safeSetState(VoidCallback fn) {
  if (!mounted) return;
  setState(fn);
}

  Future<void> _loadUser() async {
    final u = await _auth.getUser();

    var first =
        (u?['nombres'] ?? u?['nombre'] ?? u?['name'] ?? '').toString().trim();
    var last = (u?['apellidos'] ?? u?['apellido'] ?? '').toString().trim();

    if (last.isEmpty && first.contains(' ')) {
      final parts = first.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        last = parts.removeLast();
        first = parts.join(' ');
      }
    }

    _firstNameCtrl.text = first;
    _lastNameCtrl.text = last;
    _emailCtrl.text = (u?['correo'] ?? u?['email'] ?? '').toString();
    _phoneCtrl.text = (u?['telefono'] ?? u?['phone'] ?? '').toString();

    if (mounted) setState(() {});
  }

  InputDecoration _dec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Palette.kSub),
      prefixIcon: icon != null ? Icon(icon, color: Palette.kSub) : null,
      filled: true,
      fillColor: Palette.kField,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.kAccent, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.kBorder),
      ),
    );
  }

Future<void> _onSave() async {
  if (_locked || _saving || _sendingOtp) return; // 🔒 evita taps repetidos
  if (!_formKey.currentState!.validate()) return;

  final email = _emailCtrl.text.trim();
  if (email.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correo inválido')),
    );
    return;
  }

  // 1) Generar/enviar OTP
  safeSetState(() => _sendingOtp = true);  // 🔹 empieza loading en botón
  try {
    await _otpService.sendOtp(email);
    if (!mounted) return;
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo enviar el OTP: $e')),
    );
    safeSetState(() => _sendingOtp = false); // 🔹 libera botón al fallar
    return;
  }
  safeSetState(() => _sendingOtp = false);   // 🔹 detén loading antes de navegar

  // 2) Abrir OTP
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => OtpVerifyScreen(
        length: _otpLen,
        email: email,
        otpService: _otpService,
        title: 'Verificación',
        subtitle:
            'Ingresa el código de $_otpLen dígitos enviado a $email para aplicar los cambios.',
        canResend: true,
        resendSeconds: 45,
      ),
    ),
  );
  if (!mounted) return;

  if (ok != true) return;

  // 3) Guardar cambios si OTP válido
  safeSetState(() => _saving = true);
  try {
    await _auth.updateContactInfo(
      nombres: _firstNameCtrl.text.trim(),
      apellidos: _lastNameCtrl.text.trim(),
      correo: email,
      telefono: _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Datos actualizados')));
    Navigator.pop(context);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
  } finally {
    safeSetState(() => _saving = false);
  }
}

 @override
  Widget build(BuildContext context) {
    final readOnly = _locked || _saving;

    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        title: const Text('Mis datos'),
        backgroundColor: Palette.kAccent,
        foregroundColor: Palette.kBg,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : () => setState(() => _locked = !_locked),
            icon: Icon(
              _locked ? Icons.lock_outline : Icons.lock_open_outlined,
              color: _saving ? Palette.kMuted : Palette.kBg,
            ),
            label: Text(
              _locked ? 'Habilitar edición' : 'Bloquear',
              style: TextStyle(
                color: _saving ? Palette.kMuted : Palette.kBg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Encabezado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Palette.kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Palette.kBorder),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Palette.kPrimary, Palette.kAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Actualiza tu información de contacto',
                      style: TextStyle(
                        color: Palette.kTitle,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_locked)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.kAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.kAccent.withOpacity(0.35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Palette.kAccent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los campos están bloqueados. Toca "Habilitar edición" para modificarlos.',
                        style: TextStyle(color: Palette.kTitle),
                      ),
                    ),
                  ],
                ),
              ),
            if (_locked) const SizedBox(height: 10),

            // Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Correo (no editable)
                  TextFormField(
                    controller: _emailCtrl,
                    enabled: false,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec('Correo', icon: Icons.alternate_email)
                        .copyWith(
                      suffixIcon: const Tooltip(
                        message: 'No editable',
                        child: Icon(Icons.lock_outline, color: Palette.kMuted),
                      ),
                      helperText:
                          'Este dato está verificado y no puede editarse',
                      helperStyle: const TextStyle(color: Palette.kSub),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nombres
                  TextFormField(
                    controller: _firstNameCtrl,
                    readOnly: readOnly,
                    decoration: _dec('Nombres', icon: Icons.badge_outlined),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa tus nombres' : null,
                  ),
                  const SizedBox(height: 12),

                  // Apellidos
                  TextFormField(
                    controller: _lastNameCtrl,
                    readOnly: readOnly,
                    decoration: _dec('Apellidos', icon: Icons.perm_identity),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa tus apellidos' : null,
                  ),
                  const SizedBox(height: 12),

                  // Teléfono
                  TextFormField(
                    controller: _phoneCtrl,
                    readOnly: readOnly,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dec('Teléfono', icon: Icons.phone_outlined),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Ingresa tu teléfono';
                      if (s.length < 7) return 'Teléfono inválido';
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Guardar
           SizedBox(
  width: double.infinity,
  child: FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: Palette.kPrimary,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    onPressed: (_locked || _saving || _sendingOtp) ? null : _onSave, // 🔒
    icon: (_saving || _sendingOtp)
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : const Icon(Icons.check, color: Colors.white),
    label: Text(
      _saving
          ? 'Guardando...'
          : (_sendingOtp ? 'Enviando código...' : 'Guardar cambios'), // 🔹 texto dinámico
    ),
  ),
),

          ],
        ),
      ),
    );
  }
}