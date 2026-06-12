import 'package:enjoy/screens/otp_screen.dart';
import 'package:enjoy/widgets/branded_modal.dart';
import 'package:flutter/material.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/otp_service.dart';

enum RecoveryMode { cliente, empresa }

class RecuperarCuentaScreen extends StatefulWidget {
  /// Si viene true, la pantalla arranca en modo EMPRESA (heredado del login).
  final bool initialEmpresa;
  const RecuperarCuentaScreen({super.key, this.initialEmpresa = false});

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

  late RecoveryMode _mode;
  bool _loading = false;
  bool _otpOk = false;
  bool _showPass = false;
  bool _showPass2 = false;

  static const int _otpLen = 5;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialEmpresa ? RecoveryMode.empresa : RecoveryMode.cliente;
  }

  bool get _esEmpresa => _mode == RecoveryMode.empresa;

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
    final p = (v ?? '').trim();
    if (p.isEmpty) return 'Ingresa tu nueva contraseña';
    if (p.length < 8) return 'Usa al menos 8 caracteres';
    if (!RegExp(r'[a-z]').hasMatch(p)) return 'Incluye una letra minúscula';
    if (!RegExp(r'[A-Z]').hasMatch(p)) return 'Incluye una letra mayúscula';
    if (!RegExp(r'\d').hasMatch(p)) return 'Incluye un número';
    return null;
  }

  String? _pass2Val(String? v) {
    if (v == null || v.trim().isEmpty) return 'Repite tu nueva contraseña';
    if (v != _passCtrl.text.trim()) return 'Las contraseñas no coinciden';
    return null;
  }

  /// Checklist en vivo de los requisitos de una contraseña segura.
  Widget _requisitosClave() {
    final ec = context.ec;
    final p = _passCtrl.text;
    final reglas = <(String, bool)>[
      ('Al menos 8 caracteres', p.length >= 8),
      ('Una letra mayúscula', RegExp(r'[A-Z]').hasMatch(p)),
      ('Una letra minúscula', RegExp(r'[a-z]').hasMatch(p)),
      ('Un número', RegExp(r'\d').hasMatch(p)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: reglas.map((r) {
        final ok = r.$2;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 15, color: ok ? ec.green : ec.textMute),
              const SizedBox(width: 6),
              Text(r.$1,
                  style: EnjoyTheme.body(
                      size: 12, color: ok ? ec.green : ec.textMute)),
            ],
          ),
        );
      }).toList(),
    );
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

  // Modal: si el correo tiene cuenta de cliente Y empresa, pregunta cuál.
  Future<RecoveryMode?> _chooseTypeSheet() {
    final ec = context.ec;
    return showModalBottomSheet<RecoveryMode>(
      context: context,
      backgroundColor: ec.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ec.strokeStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('¿Qué cuenta quieres recuperar?',
                  style: EnjoyTheme.heading(
                      size: 18, weight: FontWeight.w800, color: ec.text)),
              const SizedBox(height: 4),
              Text('Este correo tiene cuenta de cliente y de empresa.',
                  style: EnjoyTheme.body(size: 13, color: ec.textSoft)),
              const SizedBox(height: 16),
              ListRowTile(
                leading: const IconBox(Icons.person_rounded, accent: true),
                title: 'Cuenta de cliente',
                trailing: Icon(Icons.chevron_right_rounded, color: ec.textMute),
                onTap: () => Navigator.pop(ctx, RecoveryMode.cliente),
              ),
              const SizedBox(height: 10),
              ListRowTile(
                leading: const IconBox(Icons.storefront_rounded),
                title: 'Cuenta de empresa',
                trailing: Icon(Icons.chevron_right_rounded, color: ec.textMute),
                onTap: () => Navigator.pop(ctx, RecoveryMode.empresa),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendOtpAndValidate() async {
    if (!_formKey.currentState!.validate()) return;

    final correo = _correoCtrl.text.trim();
    setState(() => _loading = true);
    try {
      // Detecta el tipo de cuenta por el correo (cliente/empresa).
      final types = await _auth.checkAccountTypes(correo);
      if (!mounted) return;
      if (!types.cliente && !types.usuario) {
        setState(() => _loading = false);
        _snack('No encontramos una cuenta con ese correo.');
        return;
      }
      if (types.cliente && types.usuario) {
        final m = await _chooseTypeSheet();
        if (m == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        _mode = m;
      } else {
        _mode = types.cliente ? RecoveryMode.cliente : RecoveryMode.empresa;
      }
      if (mounted) setState(() {});

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
    final ec = context.ec;
    return EnjoyScaffold(
      appBar: const EnjoyAppBar(title: 'Recuperar credenciales'),
      padding: EdgeInsets.zero,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Stepper de pasos ──
                Steps(count: 2, current: _otpOk ? 2 : 1),
                const SizedBox(height: 16),
                Text(
                  _esEmpresa ? 'CUENTA DE EMPRESA' : 'CUENTA DE CLIENTE',
                  style: EnjoyTheme.body(
                          size: 11,
                          weight: FontWeight.w800,
                          color: ec.orangeSoft)
                      .copyWith(letterSpacing: 0.6),
                ),
                const SizedBox(height: 4),
                Text(
                  _otpOk
                      ? 'Crea tu nueva contraseña'
                      : 'Verifica tu identidad para continuar',
                  style: EnjoyTheme.body(
                      size: 13, color: ec.textSoft, height: 1.3),
                ),
                const SizedBox(height: 18),

                // ── Paso 1: Email ──
                if (!_otpOk)
                  _Card(
                    icon: Icons.mail_outline,
                    title: 'Ingresa tu correo',
                    subtitle:
                        'Te enviaremos un código para verificar tu identidad.',
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _correoCtrl,
                            validator: _emailVal,
                            keyboardType: TextInputType.emailAddress,
                            cursorColor: ec.orange,
                            style: EnjoyTheme.body(size: 14, color: ec.text),
                            decoration: const InputDecoration(
                              hintText: 'email@ejemplo.com',
                              prefixIcon:
                                  Icon(Icons.alternate_email, size: 20),
                            ),
                            onFieldSubmitted: (_) => _sendOtpAndValidate(),
                          ),
                          const SizedBox(height: 16),
                          EnjoyButton(
                            label: _loading ? 'Enviando…' : 'Enviar código',
                            icon: Icons.send,
                            loading: _loading,
                            onPressed: _loading ? null : _sendOtpAndValidate,
                          ),
                        ],
                      ),
                    ),
                  ),

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
                          cursorColor: ec.orange,
                          onChanged: (_) => setState(() {}),
                          style: EnjoyTheme.body(size: 14, color: ec.text),
                          decoration: InputDecoration(
                            hintText: 'Nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _showPass
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: ec.textMute,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _showPass = !_showPass),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _requisitosClave(),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pass2Ctrl,
                          obscureText: !_showPass2,
                          cursorColor: ec.orange,
                          style: EnjoyTheme.body(size: 14, color: ec.text),
                          decoration: InputDecoration(
                            hintText: 'Repetir contraseña',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _showPass2
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: ec.textMute,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _showPass2 = !_showPass2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        EnjoyButton(
                          label: _loading
                              ? 'Actualizando…'
                              : 'Actualizar contraseña',
                          icon: Icons.check,
                          loading: _loading,
                          onPressed: _loading ? null : _resetPassword,
                        ),
                      ],
                    ),
                  ),
              ],
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
    final ec = context.ec;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconBox(icon, size: 36, radius: 10, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: EnjoyTheme.heading(
                      size: 16, weight: FontWeight.w700, color: ec.text)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(subtitle, style: EnjoyTheme.body(size: 13, color: ec.textSoft)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
