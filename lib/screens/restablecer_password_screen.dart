// lib/screens/auth/restablecer_password_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:enjoy/services/auth_service.dart';

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

  final _bg = const Color(0xFFF6F9FF);
  final _primary = const Color(0xFF2E6BE6);
  final _text = const Color(0xFF111827);
  final _muted = const Color(0xFF6B7280);
  final _pill = const Color(0xFFD9E6FF);

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

  Widget _pillField({
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(color: _pill, borderRadius: BorderRadius.circular(28)),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Icon(icon, color: _muted), const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              border: InputBorder.none, hintText: hint,
              hintStyle: TextStyle(color: _muted), isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: TextStyle(color: _text),
          ),
        ),
        if (onToggle != null)
          IconButton(
            onPressed: onToggle,
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _muted),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _text,
        title: const Text('Restablecer contraseña'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ingresa el código y tu nueva contraseña',
                      style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  Text('Código de verificación', style: TextStyle(color: _muted)),
                  const SizedBox(height: 8),
                  _pillField(hint: 'Código recibido por correo', controller: _codeCtrl, icon: Icons.verified_outlined),
                  const SizedBox(height: 16),

                  Text('Nueva contraseña', style: TextStyle(color: _muted)),
                  const SizedBox(height: 8),
                  _pillField(
                    hint: 'Mínimo 6 caracteres',
                    controller: _pwdCtrl, icon: Icons.lock_outline,
                    obscure: _obscure1, onToggle: () => setState(() => _obscure1 = !_obscure1),
                  ),
                  const SizedBox(height: 16),

                  Text('Confirmar contraseña', style: TextStyle(color: _muted)),
                  const SizedBox(height: 8),
                  _pillField(
                    hint: 'Repite tu contraseña',
                    controller: _pwd2Ctrl, icon: Icons.lock_outline,
                    obscure: _obscure2, onToggle: () => setState(() => _obscure2 = !_obscure2),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary, foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Restablecer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
