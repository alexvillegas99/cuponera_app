import 'package:flutter/material.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import '../ui/palette.dart';

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
  bool _googleLoading = false;

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

  String get _forgotText => '¿Olvidaste tu contraseña?';

  Future<void> _doLogin() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('Ingresa tus credenciales.');
      return;
    }

    setState(() => _loading = true);
    try {
      _mode == LoginMode.cliente
          ? await _auth.loginCliente(_userCtrl.text.trim(), _passCtrl.text, context)
          : await _auth.loginEmpresa(_userCtrl.text.trim(), _passCtrl.text, context);
    } catch (_) {
      _snack('Credenciales inválidas. Inténtalo nuevamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    await _auth.continueAsGuest();
    if (mounted) context.go('/home_guest');
  }

  Future<void> _doGoogleLogin() async {
    setState(() => _googleLoading = true);
    try {
      if (_mode == LoginMode.cliente) {
        final result = await _auth.loginClienteWithGoogle(context);
        if (result['registered'] == false && mounted) {
          context.push('/registro-cliente', extra: result);
        }
      } else {
        await _auth.loginUsuarioWithGoogle(context);
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kPrimary,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // ── Logo + marca ──
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset('assets/img/logoeny.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enjoy',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Card principal ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título
                        Text(
                          _headline,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Palette.kTitle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ingresa tus credenciales para continuar',
                          style: TextStyle(color: Palette.kMuted, fontSize: 14),
                        ),

                        const SizedBox(height: 24),

                        // ── Segmento ──
                        Container(
                          decoration: BoxDecoration(
                            color: Palette.kBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              _Segment(
                                text: 'Cliente',
                                active: _mode == LoginMode.cliente,
                                onTap: () => setState(() => _mode = LoginMode.cliente),
                              ),
                              _Segment(
                                text: 'Empresa',
                                active: _mode == LoginMode.empresa,
                                onTap: () => setState(() => _mode = LoginMode.empresa),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Email ──
                        _Field(
                          controller: _userCtrl,
                          hint: _userHint,
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),

                        // ── Password ──
                        _Field(
                          controller: _passCtrl,
                          hint: 'Contraseña',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Palette.kMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Forgot ──
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/recuperar'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _forgotText,
                              style: const TextStyle(
                                color: Palette.kAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Botón CTA ──
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _doLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Palette.kAccent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Palette.kAccent.withOpacity(0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Text(
                                    'Iniciar sesión',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),

                        // ── Google Sign-In ──
                        ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Palette.kBg)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('o', style: TextStyle(color: Palette.kMuted, fontSize: 13)),
                              ),
                              const Expanded(child: Divider(color: Palette.kBg)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: (_loading || _googleLoading) ? null : _doGoogleLogin,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFDDDDDD)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                backgroundColor: Colors.white,
                              ),
                              child: _googleLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.kAccent),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF4285F4),
                                          ),
                                          child: const Text(
                                            'G',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Continuar con Google',
                                          style: TextStyle(
                                            color: Palette.kTitle,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],

                        // ── Invitado (solo modo cliente) ──
                        if (_mode == LoginMode.cliente) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Palette.kMuted.withOpacity(0.3))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('o explora sin cuenta', style: TextStyle(color: Palette.kMuted, fontSize: 12)),
                              ),
                              Expanded(child: Divider(color: Palette.kMuted.withOpacity(0.3))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _loading ? null : _continueAsGuest,
                              icon: const Icon(Icons.explore_outlined, size: 20),
                              label: const Text(
                                'Continuar como invitado',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Palette.kPrimary,
                                side: BorderSide(color: Palette.kPrimary.withOpacity(0.4), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── Footer ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _mode == LoginMode.cliente
                                  ? '¿No tienes cuenta? '
                                  : '¿Tu empresa no tiene acceso? ',
                              style: const TextStyle(color: Palette.kMuted, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () => context.push(
                                _mode == LoginMode.cliente
                                    ? '/registro-cliente'
                                    : '/solicitud-empresa',
                              ),
                              child: Text(
                                _mode == LoginMode.cliente ? 'Regístrate' : 'Solicitar acceso',
                                style: const TextStyle(
                                  color: Palette.kAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

// ───────────── Segment toggle
class _Segment extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _Segment({required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Palette.kAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: active ? Colors.white : Palette.kMuted,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────── Input field
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      cursorColor: Palette.kAccent,
      style: const TextStyle(color: Palette.kTitle, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: Palette.kMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Palette.kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.kAccent, width: 1.5),
        ),
      ),
    );
  }
}
