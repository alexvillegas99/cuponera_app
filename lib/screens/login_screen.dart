import 'package:flutter/material.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:go_router/go_router.dart';

enum LoginMode { cliente, empresa }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  LoginMode _mode = LoginMode.cliente;
  bool _obscure = true;
  bool _loading = false;

  // Paleta
  final Color _primary = const Color(0xFF010F23);
  final Color _accent = const Color(0xFF173A5E);
  final Color _bg = const Color(0xFFF3F4F6);
  final Color _pill = const Color(0xFFE0E7EF);
  final Color _text = const Color(0xFF111827);
  final Color _muted = const Color(0xFF6B7280);

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String get _headline =>
      _mode == LoginMode.cliente ? 'Iniciar sesión' : 'Acceso empresas';

  String get _userHint =>
      _mode == LoginMode.cliente ? 'Correo electrónico' : 'Correo corporativo';

  String get _forgotText => _mode == LoginMode.cliente
      ? '¿Olvidaste tu contraseña?'
      : '¿Olvidaste tu contraseña (empresa)?';

  Future<void> _doLogin() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _alert('Campos requeridos', 'Ingresa tus credenciales.');
      return;
    }

    setState(() => _loading = true);
    try {
      _mode == LoginMode.cliente
          ? await _auth.loginCliente(
              _userCtrl.text.trim(),
              _passCtrl.text,
              context,
            )
          : await _auth.loginEmpresa(
              _userCtrl.text.trim(),
              _passCtrl.text,
              context,
            );
    } catch (_) {
      _alert(
        'Error',
        'Credenciales inválidas. Inténtalo nuevamente.',
      );
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 14,
                shadowColor: _primary.withOpacity(.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LOGO
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: _primary, width: 2),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  'assets/img/logoeny.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Enjoy',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _text,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      Text(
                        _headline,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ingresa tus credenciales para continuar',
                        style: TextStyle(color: _muted),
                      ),

                      const SizedBox(height: 22),

                      // SEGMENTO
                      Container(
                        decoration: BoxDecoration(
                          color: _pill,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _SegmentButton(
                              text: 'Cliente',
                              active: _mode == LoginMode.cliente,
                              activeColor: _primary,
                              onTap: () =>
                                  setState(() => _mode = LoginMode.cliente),
                            ),
                            _SegmentButton(
                              text: 'Empresa',
                              active: _mode == LoginMode.empresa,
                              activeColor: _primary,
                              onTap: () =>
                                  setState(() => _mode = LoginMode.empresa),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      _InputField(
                        controller: _userCtrl,
                        hint: _userHint,
                        icon: Icons.mail_outline,
                        textColor: _text,
                        hintColor: _muted,
                      ),
                      const SizedBox(height: 14),
                      _InputField(
                        controller: _passCtrl,
                        hint: 'Contraseña',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        onToggle: () =>
                            setState(() => _obscure = !_obscure),
                        textColor: _text,
                        hintColor: _muted,
                      ),

                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/recuperar'),
                          child: Text(
                            _forgotText,
                            style: TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // BOTÓN
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              colors: [_primary, _accent],
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _loading ? null : _doLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: _loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : const Text(
                                    'Iniciar sesión',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // FOOTER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _mode == LoginMode.cliente
                                ? '¿No tienes cuenta?'
                                : '¿Tu empresa no tiene acceso?',
                            style: TextStyle(color: _muted),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => context.push(
                              _mode == LoginMode.cliente
                                  ? '/registro-cliente'
                                  : '/solicitud-empresa',
                            ),
                            child: Text(
                              _mode == LoginMode.cliente
                                  ? 'Regístrate'
                                  : 'Solicitar acceso',
                              style: TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================== COMPONENTES ==================

class _SegmentButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;

  const _SegmentButton({
    required this.text,
    required this.active,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: active ? Colors.white : activeColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggle;
  final Color textColor;
  final Color hintColor;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.textColor,
    required this.hintColor,
    this.obscure = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, color: hintColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                hintStyle: TextStyle(color: hintColor),
              ),
              style: TextStyle(color: textColor),
            ),
          ),
          if (onToggle != null)
            IconButton(
              icon: Icon(
                obscure ? Icons.visibility : Icons.visibility_off,
                color: hintColor,
              ),
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }
}
