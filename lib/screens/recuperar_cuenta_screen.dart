// lib/screens/auth/recuperar_cuenta_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:enjoy/services/auth_service.dart';

enum RecoveryMode { cliente, empresa }

class RecuperarCuentaScreen extends StatefulWidget {
  const RecuperarCuentaScreen({super.key});

  @override
  State<RecuperarCuentaScreen> createState() => _RecuperarCuentaScreenState();
}

class _RecuperarCuentaScreenState extends State<RecuperarCuentaScreen> {
  final _auth = AuthService();
  final _correoCtrl = TextEditingController();

  RecoveryMode _mode = RecoveryMode.cliente;
  bool _loading = false;

  final _bg = const Color(0xFFF6F9FF);
  final _primary = const Color(0xFF2E6BE6);
  final _text = const Color(0xFF111827);
  final _muted = const Color(0xFF6B7280);
  final _pill = const Color(0xFFD9E6FF);

  @override
  void dispose() {
    _correoCtrl.dispose();
    super.dispose();
  }

  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
    final rx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return rx.hasMatch(v.trim()) ? null : 'Correo inválido';
  }

  Future<void> _submit() async {
    final correo = _correoCtrl.text.trim();
    final err = _emailVal(correo);
    if (err != null) {
      _alert('Dato requerido', err);
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.startRecovery(correo, isCliente: _mode == RecoveryMode.cliente);
      if (!mounted) return;
      await _ok('Correo enviado', 'Revisa tu bandeja e ingresa el código que te enviamos.');
      context.push('/restablecer'); // a la pantalla de código+password
    } catch (e) {
      _alert('No pudimos iniciar la recuperación', e.toString());
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continuar'))],
      ),
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
        title: const Text('Recuperar cuenta'),
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
                  Text('¿Olvidaste tu contraseña?', style: TextStyle(color: _text, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Te enviaremos un código para restablecer tu contraseña.',
                      style: TextStyle(color: _muted)),
                  const SizedBox(height: 18),

                  // Selector Cliente/Empresa
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _primary.withOpacity(.15)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _SegmentButton(
                          text: 'Cliente',
                          active: _mode == RecoveryMode.cliente,
                          onTap: () => setState(() => _mode = RecoveryMode.cliente),
                          activeColor: _primary,
                        ),
                        _SegmentButton(
                          text: 'Empresa',
                          active: _mode == RecoveryMode.empresa,
                          onTap: () => setState(() => _mode = RecoveryMode.empresa),
                          activeColor: _primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text('Correo', style: TextStyle(color: _muted)),
                  const SizedBox(height: 8),
                  _PillField(
                    hint: _mode == RecoveryMode.cliente ? 'email@ejemplo.com' : 'usuario@empresa.com',
                    controller: _correoCtrl,
                    icon: Icons.alternate_email,
                    pillColor: _pill, textColor: _text, hintColor: _muted,
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
                          : const Text('Enviar código', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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

// Reutilizamos los auxiliares del login
class _SegmentButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;
  const _SegmentButton({required this.text, required this.active, required this.onTap, required this.activeColor});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: active ? activeColor : Colors.transparent, borderRadius: BorderRadius.circular(999)),
          child: Center(
            child: Text(text, style: TextStyle(color: active ? Colors.white : activeColor, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _PillField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final Color pillColor, textColor, hintColor;
  const _PillField({
    super.key, required this.hint, required this.controller, required this.icon,
    required this.pillColor, required this.textColor, required this.hintColor
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(color: pillColor, borderRadius: BorderRadius.circular(28)),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Icon(icon, color: hintColor), const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              border: InputBorder.none, hintText: hint,
              hintStyle: TextStyle(color: hintColor), isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: TextStyle(color: textColor),
          ),
        ),
      ]),
    );
  }
}
