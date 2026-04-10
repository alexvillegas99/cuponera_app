import 'dart:async';
import 'package:enjoy/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/otp_service.dart';
import '../../../ui/palette.dart';

class EditContactWithOtpScreen extends StatefulWidget {
  const EditContactWithOtpScreen({super.key});

  @override
  State<EditContactWithOtpScreen> createState() =>
      _EditContactWithOtpScreenState();
}

class _EditContactWithOtpScreenState extends State<EditContactWithOtpScreen> {
  final _auth = AuthService();
  final _otpService = OtpService();

  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _locked = true;
  bool _saving = false;
  bool _sendingOtp = false;

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

  void _safeSetState(VoidCallback fn) {
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

    // Normalizar teléfono: +5939XXXXXXXX → 09XXXXXXXX para mostrar solo número local
    final rawPhone = (u?['telefono'] ?? u?['phone'] ?? '').toString().trim();
    if (rawPhone.startsWith('+593') && rawPhone.length == 13) {
      _phoneCtrl.text = '0${rawPhone.substring(4)}';
    } else {
      _phoneCtrl.text = rawPhone;
    }

    if (mounted) setState(() {});
  }

  InputDecoration _fieldDec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
      prefixIcon: icon != null
          ? Icon(icon, color: Palette.kMuted, size: 18)
          : null,
      filled: true,
      fillColor: Palette.kField,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.kAccent, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.kBorder),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  Future<void> _onSave() async {
    if (_locked || _saving || _sendingOtp) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo inválido')),
      );
      return;
    }

    _safeSetState(() => _sendingOtp = true);
    try {
      await _otpService.sendOtp(email);
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el OTP: $e')),
      );
      _safeSetState(() => _sendingOtp = false);
      return;
    }
    _safeSetState(() => _sendingOtp = false);

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

    _safeSetState(() => _saving = true);
    try {
      // Convertir 09XXXXXXXX → +5939XXXXXXXX
      final localPhone = _phoneCtrl.text.trim();
      final intlPhone = localPhone.startsWith('0')
          ? '+593${localPhone.substring(1)}'
          : localPhone;

      await _auth.updateContactInfo(
        nombres: _firstNameCtrl.text.trim(),
        apellidos: _lastNameCtrl.text.trim(),
        correo: email,
        telefono: intlPhone,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos actualizados')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    } finally {
      _safeSetState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _sendingOtp;
    final readOnly = _locked || busy;

    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Palette.kPrimary,
        title: const Text(
          'Editar perfil',
          style: TextStyle(
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [

            // ── Email (solo lectura) ──────────────────────────────
            _buildEmailRow(),

            const SizedBox(height: 12),

            // ── Toggle lock ───────────────────────────────────────
            _buildLockToggle(busy),

            const SizedBox(height: 12),

            // ── Form card ─────────────────────────────────────────
            _buildFormCard(readOnly),

            const SizedBox(height: 20),

            // ── Botón guardar ─────────────────────────────────────
            _buildSaveButton(busy),
          ],
        ),
      ),
    );
  }

  // ── Email row ──────────────────────────────────────────────────────
  Widget _buildEmailRow() {
    final email = _emailCtrl.text.isEmpty ? '—' : _emailCtrl.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Palette.kPrimary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.alternate_email_rounded,
              color: Palette.kPrimary,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Correo electrónico',
                  style: TextStyle(color: Palette.kMuted, fontSize: 11),
                ),
                const SizedBox(height: 1),
                Text(
                  email,
                  style: const TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: Colors.green, size: 12),
                SizedBox(width: 4),
                Text(
                  'Verificado',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Lock toggle ────────────────────────────────────────────────────
  Widget _buildLockToggle(bool busy) {
    return GestureDetector(
      onTap: busy ? null : () => setState(() => _locked = !_locked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _locked
              ? Palette.kAccent.withOpacity(0.06)
              : Palette.kPrimary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _locked
                ? Palette.kAccent.withOpacity(0.25)
                : Palette.kPrimary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _locked
                    ? Palette.kAccent.withOpacity(0.12)
                    : Palette.kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _locked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                color: _locked ? Palette.kAccent : Palette.kPrimary,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _locked ? 'Campos bloqueados' : 'Edición habilitada',
                    style: TextStyle(
                      color: _locked ? Palette.kAccent : Palette.kPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _locked
                        ? 'Toca para habilitar la edición'
                        : 'Toca para bloquear los campos',
                    style: const TextStyle(
                      color: Palette.kMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _locked ? Palette.kAccent : Palette.kPrimary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Form card ──────────────────────────────────────────────────────
  Widget _buildFormCard(bool readOnly) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          // Section header
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Palette.kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Palette.kAccent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Información personal',
                style: TextStyle(
                  color: Palette.kTitle,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _firstNameCtrl,
                  readOnly: readOnly,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDec('Nombres', icon: Icons.badge_outlined),
                  style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa tus nombres'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameCtrl,
                  readOnly: readOnly,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      _fieldDec('Apellidos', icon: Icons.perm_identity_rounded),
                  style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa tus apellidos'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  readOnly: readOnly,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                  decoration: _fieldDec('Número local', icon: Icons.phone_outlined).copyWith(
                    counterText: '',
                    hintText: '0999999999',
                    hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
                    prefix: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Palette.kBorder)),
                      ),
                      child: const Text(
                        '+593',
                        style: TextStyle(
                          color: Palette.kTitle,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Ingresa tu teléfono';
                    if (!RegExp(r'^0[2-9]\d{8}$').hasMatch(s)) {
                      return 'Número inválido — ej: 0999999999';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────────
  Widget _buildSaveButton(bool busy) {
    final enabled = !_locked && !busy;
    return GestureDetector(
      onTap: enabled ? _onSave : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Palette.kAccent, Palette.kAccentLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : Palette.kBorder,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Palette.kAccent.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                Icons.check_rounded,
                color: enabled ? Colors.white : Palette.kMuted,
                size: 18,
              ),
            const SizedBox(width: 8),
            Text(
              _saving
                  ? 'Guardando...'
                  : _sendingOtp
                      ? 'Enviando código...'
                      : 'Guardar cambios',
              style: TextStyle(
                color: enabled ? Colors.white : Palette.kMuted,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
