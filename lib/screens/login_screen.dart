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

  // Paleta “azul” tipo referencia
// Paleta “azul oscuro” tipo referencia
final Color _primary = const Color(0xFF010F23); // azul oscuro principal
final Color _accent  = const Color(0xFF173A5E); // azul medio (para botones hover / acentos)
final Color _bg      = const Color(0xFFF3F4F6); // fondo claro (hueso grisáceo)
final Color _pill    = const Color(0xFFE0E7EF); // pill inputs gris-azulado
final Color _text    = const Color(0xFF111827); // texto principal (gris muy oscuro)
final Color _muted   = const Color(0xFF6B7280); // texto secundario (gris medio)

 
  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String get _forgotText => _mode == LoginMode.cliente
      ? '¿Olvidaste tu contraseña?'
      : '¿Olvidaste tu contraseña (empresa)?';

  String get _headline =>
      _mode == LoginMode.cliente ? 'Iniciar sesión' : 'Acceso empresas';
  String get _userHint =>
      _mode == LoginMode.cliente ? 'Correo' : 'Correo corporativo';

  Future<void> _doLogin() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (user.isEmpty || pass.isEmpty) {
      _alert('Campos requeridos', 'Ingresa tus credenciales.');
      return;
    }
    setState(() => _loading = true);
    try {
      if (_mode == LoginMode.cliente) {
        await _auth.loginCliente(
          user,
          pass,
          context,
        ); // navega a la ruta correcta
      } else {
        await _auth.loginEmpresa(
          user,
          pass,
          context,
        ); // navega a la ruta correcta
      }
    } catch (_) {
      _alert(
        'Error de inicio de sesión',
        'Credenciales inválidas. Verifica tus datos e inténtalo nuevamente.',
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
      resizeToAvoidBottomInset: true, // ← fondo ya no se mueve
      body: Stack(
        children: [
          // ======= Formas decorativas azules (arriba-derecha / abajo-izquierda) =======
          Positioned(
            right: -60,
            top: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(.35),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: -60,
            child: Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),

          // ====================== Contenido ======================
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo + nombre
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: _primary, // color del borde
                                width: 2, // grosor del borde
                              ),
                            ), 
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: ClipOval(
                                child: Image.asset('assets/img/logoeny.png'),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),
                          Text(
                            'Enjoy',
                            style: TextStyle(
                              color: _text,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),

                      Text(
                        _headline,
                        style: TextStyle(
                          color: _text,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Por favor, ingresa tus credenciales para continuar.',
                        style: TextStyle(color: _muted),
                      ),

                      const SizedBox(height: 20),

                      // ===== Selector Cliente/Empresa (pill segment) =====
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
                              active: _mode == LoginMode.cliente,
                              onTap: () =>
                                  setState(() => _mode = LoginMode.cliente),
                              activeColor: _primary,
                            ),
                            _SegmentButton(
                              text: 'Empresa',
                              active: _mode == LoginMode.empresa,
                              onTap: () =>
                                  setState(() => _mode = LoginMode.empresa),
                              activeColor: _primary,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ===== Inputs estilo "pill" =====
                      Text('Usuario', style: TextStyle(color: _muted)),
                      const SizedBox(height: 8),
                      _PillField(
                        hint: _userHint,
                        controller: _userCtrl,
                        icon: Icons.person_outline,
                        pillColor: _pill,
                        textColor: _text,
                        hintColor: _muted,
                      ),
                      const SizedBox(height: 16),

                      Text('Contraseña', style: TextStyle(color: _muted)),
                      const SizedBox(height: 8),
                      _PillField(
                        hint: '••••••••',
                        controller: _passCtrl,
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        onToggleObscure: () =>
                            setState(() => _obscure = !_obscure),
                        pillColor: _pill,
                        textColor: _text,
                        hintColor: _muted,
                      ),

                      const SizedBox(height: 12),

                      // Link recuperar
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/recuperar'),
                          child: Text(
                            _forgotText, // usa el texto dinámico según cliente/empresa
                            style: TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // ===== Botón login grande con flecha =====
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _doLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
                                      'Login  ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_right_alt_rounded,
                                      size: 26,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Signup
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _mode == LoginMode.cliente
                                ? "¿No tienes cuenta?"
                                : "¿Tu empresa no tiene acceso?",
                            style: TextStyle(color: _muted),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              if (_mode == LoginMode.cliente) {
                                context.push('/registro-cliente');
                              } else {
                                context.push('/solicitud-empresa');
                              }
                            },
                            child: Text(
                              _mode == LoginMode.cliente
                                  ? 'Regístrate'
                                  : 'Solicitar acceso',
                              style: TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
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
        ],
      ),
    );
  }
}

// =============== Widgets auxiliares ===============

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

class _PillField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final Color pillColor;
  final Color textColor;
  final Color hintColor;

  const _PillField({
    super.key,
    required this.hint,
    required this.controller,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    required this.pillColor,
    required this.textColor,
    required this.hintColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: hintColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: hintColor),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: TextStyle(color: textColor),
            ),
          ),
          if (onToggleObscure != null)
            IconButton(
              icon: Icon(
                obscure ? Icons.visibility : Icons.visibility_off,
                color: hintColor,
              ),
              onPressed: onToggleObscure,
            ),
        ],
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _SocialIcon({required this.color, required this.icon, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Icon(icon, color: color),
    );
  }
}
