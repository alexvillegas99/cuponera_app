import 'dart:async';
import 'package:enjoy/screens/otp_screen.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/otp_service.dart';

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

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Editar perfil'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          // ── Avatar ────────────────────────────────────────────
          _buildAvatar(busy),

          const SizedBox(height: 18),

          // ── Email (solo lectura) ──────────────────────────────
          _buildEmailRow(),

          const SizedBox(height: 12),

          // ── Toggle lock ───────────────────────────────────────
          _buildLockToggle(busy),

          const SizedBox(height: 18),

          // ── Form card ─────────────────────────────────────────
          _buildFormCard(readOnly),

          const SizedBox(height: 20),

          // ── Botón guardar ─────────────────────────────────────
          _buildSaveButton(busy),
        ],
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────
  Widget _buildAvatar(bool busy) {
    final ec = context.ec;
    final name = [_firstNameCtrl.text, _lastNameCtrl.text]
        .where((s) => s.trim().isNotEmpty)
        .join(' ');
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          EnjoyAvatar(name.isEmpty ? 'U' : name, size: 92),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: busy ? null : () => setState(() => _locked = false),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: ec.accentGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: ec.bgBottom, width: 2),
                ),
                child: Icon(Icons.edit_rounded, color: ec.onAccent, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Email row ──────────────────────────────────────────────────────
  Widget _buildEmailRow() {
    final ec = context.ec;
    final email = _emailCtrl.text.isEmpty ? '—' : _emailCtrl.text;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          const IconBox(Icons.alternate_email_rounded),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Correo electrónico',
                  style: EnjoyTheme.body(size: 11, color: ec.textMute),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: EnjoyTheme.heading(
                      size: 14, weight: FontWeight.w600, color: ec.text),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Pill('Verificado',
              variant: PillVariant.green,
              icon: Icons.verified_rounded,
              dense: true),
        ],
      ),
    );
  }

  // ── Lock toggle ────────────────────────────────────────────────────
  Widget _buildLockToggle(bool busy) {
    final ec = context.ec;
    final accent = _locked ? ec.orange : ec.green;
    return ListRowTile(
      borderColor: accent.withValues(alpha: .3),
      leading: IconBox(
        _locked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
        color: accent,
      ),
      title: _locked ? 'Campos bloqueados' : 'Edición habilitada',
      titleColor: accent,
      subtitle: _locked
          ? 'Toca para habilitar la edición'
          : 'Toca para bloquear los campos',
      trailing: Icon(Icons.chevron_right_rounded, color: accent, size: 20),
      onTap: busy ? null : () => setState(() => _locked = !_locked),
    );
  }

  // ── Form card ──────────────────────────────────────────────────────
  Widget _buildFormCard(bool readOnly) {
    final ec = context.ec;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              const IconBox(Icons.person_outline_rounded, size: 34, iconSize: 17),
              const SizedBox(width: 12),
              Text(
                'Información personal',
                style: EnjoyTheme.heading(size: 14, color: ec.text),
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
                  cursorColor: ec.orange,
                  style: EnjoyTheme.body(size: 14, color: ec.text),
                  decoration: InputDecoration(
                    labelText: 'Nombres',
                    prefixIcon: Icon(Icons.badge_outlined,
                        color: ec.orangeSoft, size: 18),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa tus nombres'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameCtrl,
                  readOnly: readOnly,
                  textCapitalization: TextCapitalization.words,
                  cursorColor: ec.orange,
                  style: EnjoyTheme.body(size: 14, color: ec.text),
                  decoration: InputDecoration(
                    labelText: 'Apellidos',
                    prefixIcon: Icon(Icons.perm_identity_rounded,
                        color: ec.orangeSoft, size: 18),
                  ),
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
                  cursorColor: ec.orange,
                  style: EnjoyTheme.body(size: 14, color: ec.text),
                  decoration: InputDecoration(
                    labelText: 'Número local',
                    counterText: '',
                    hintText: '0999999999',
                    prefixIcon: Icon(Icons.phone_outlined,
                        color: ec.orangeSoft, size: 18),
                    prefix: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: ec.stroke)),
                      ),
                      child: Text(
                        '+593',
                        style: EnjoyTheme.heading(
                            size: 14, weight: FontWeight.w700, color: ec.text),
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
    return EnjoyButton(
      label: _saving
          ? 'Guardando...'
          : _sendingOtp
              ? 'Enviando código...'
              : 'Guardar cambios',
      icon: busy ? null : Icons.check_rounded,
      loading: busy,
      onPressed: enabled ? _onSave : null,
    );
  }
}
