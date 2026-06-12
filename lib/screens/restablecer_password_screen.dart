// lib/screens/auth/restablecer_password_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/ui/enjoy.dart';

class RestablecerPasswordScreen extends StatefulWidget {
  const RestablecerPasswordScreen({super.key});

  @override
  State<RestablecerPasswordScreen> createState() => _RestablecerPasswordScreenState();
}

class _RestablecerPasswordScreenState extends State<RestablecerPasswordScreen> {
  final _auth = AuthService();
  final _codeCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    final p1 = _pwdCtrl.text;
    final p2 = _pwd2Ctrl.text;

    if (code.isEmpty) return _alert('Código requerido', 'Ingresa el código que te enviamos.');
    if (p1.length < 6) return _alert('Contraseña inválida', 'Debe tener al menos 6 caracteres.');
    if (p1 != p2) return _alert('No coinciden', 'Las contraseñas no coinciden.');

    setState(() => _loading = true);
    try {
      await _auth.completeRecovery(code, p1);
      if (!mounted) return;
      await _ok('Contraseña actualizada', 'Ahora puedes iniciar sesión con tu nueva contraseña.');
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      _alert('No pudimos restablecer', e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _alert(String t, String m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t),
        content: Text(m),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _ok(String t, String m) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t),
        content: Text(m),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Listo'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      appBar: const EnjoyAppBar(title: 'Restablecer contraseña'),
      padding: EdgeInsets.zero,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ingresa el código y tu nueva contraseña',
                    style: EnjoyTheme.heading(
                        size: 20, weight: FontWeight.w800, color: ec.text)),
                const SizedBox(height: 18),

                const FieldLabel('Código de verificación'),
                TextField(
                  controller: _codeCtrl,
                  cursorColor: ec.orange,
                  style: EnjoyTheme.body(size: 14, color: ec.text),
                  decoration: const InputDecoration(
                    hintText: 'Código recibido por correo',
                    prefixIcon: Icon(Icons.verified_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),

                const FieldLabel('Nueva contraseña'),
                TextField(
                  controller: _pwdCtrl,
                  obscureText: _obscure1,
                  cursorColor: ec.orange,
                  style: EnjoyTheme.body(size: 14, color: ec.text),
                  decoration: InputDecoration(
                    hintText: 'Mínimo 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure1
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: ec.textMute,
                          size: 20),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const FieldLabel('Confirmar contraseña'),
                TextField(
                  controller: _pwd2Ctrl,
                  obscureText: _obscure2,
                  cursorColor: ec.orange,
                  style: EnjoyTheme.body(size: 14, color: ec.text),
                  decoration: InputDecoration(
                    hintText: 'Repite tu contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure2
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: ec.textMute,
                          size: 20),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                EnjoyButton(
                  label: 'Restablecer',
                  icon: Icons.lock_reset_rounded,
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
