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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  LoginMode _mode = LoginMode.cliente;
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get _headline => _mode == LoginMode.cliente ? 'Bienvenido de vuelta' : 'Acceso empresas';

  String get _userHint =>
      _mode == LoginMode.cliente ? 'Correo electrónico' : 'Correo corporativo';

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
        backgroundColor: Palette.kPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Fondo gradiente ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Palette.kPrimary, Color(0xFF1E3A5F)],
              ),
            ),
          ),

          // ── Contenido ──
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: Column(
                      children: [
                        // ── Logo ──
                        _buildLogo(),
                        const SizedBox(height: 32),

                        // ── Card ──
                        _buildCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Palette.kAccent.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Image.asset('assets/img/logoeny.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Enjoy',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
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
              fontWeight: FontWeight.w800,
              color: Palette.kTitle,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ingresa tus credenciales para continuar',
            style: TextStyle(color: Palette.kMuted, fontSize: 13),
          ),

          const SizedBox(height: 22),

          // ── Email ──
          _Field(
            controller: _userCtrl,
            hint: _userHint,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          // ── Password ──
          _Field(
            controller: _passCtrl,
            hint: 'Contraseña',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Palette.kMuted,
                  size: 20,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Forgot ──
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.push('/recuperar'),
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  color: Palette.kAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // ── CTA Gradient ──
          _buildCta(),

          const SizedBox(height: 16),

          // ── Divider ──
          Row(
            children: [
              Expanded(child: Divider(color: Palette.kBorder, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'o continúa con',
                  style: TextStyle(color: Palette.kMuted, fontSize: 12),
                ),
              ),
              Expanded(child: Divider(color: Palette.kBorder, thickness: 1)),
            ],
          ),

          const SizedBox(height: 16),

          // ── Google ──
          _buildGoogleBtn(),

          // ── Invitado ──
          if (_mode == LoginMode.cliente) ...[
            const SizedBox(height: 12),
            _buildGuestBtn(),
          ],

          const SizedBox(height: 22),

          // ── Footer registro ──
          _buildFooter(),

          const SizedBox(height: 16),

          // ── Acceso empresas (discreto) ──
          _buildEmpresaSwitch(),
        ],
      ),
    );
  }

  Widget _buildEmpresaSwitch() {
    final isEmpresa = _mode == LoginMode.empresa;
    return GestureDetector(
      onTap: () => setState(() =>
          _mode = isEmpresa ? LoginMode.cliente : LoginMode.empresa),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 13, color: Palette.kMuted.withOpacity(0.6)),
          const SizedBox(width: 5),
          Text(
            isEmpresa ? 'Volver a acceso cliente' : 'Acceso empresas',
            style: TextStyle(
              color: Palette.kMuted.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta() {
    return GestureDetector(
      onTap: _loading ? null : _doLogin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          gradient: _loading
              ? null
              : const LinearGradient(
                  colors: [Palette.kAccent, Palette.kAccentLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: _loading ? Palette.kAccent.withOpacity(0.5) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _loading
              ? []
              : [
                  BoxShadow(
                    color: Palette.kAccent.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Center(
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login_rounded, color: Colors.white, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGoogleBtn() {
    return GestureDetector(
      onTap: (_loading || _googleLoading) ? null : _doGoogleLogin,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.kBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: _googleLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.kAccent),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/img/google_logo.webp',
                      width: 22,
                      height: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Continuar con Google',
                      style: TextStyle(
                        color: Palette.kTitle,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGuestBtn() {
    return GestureDetector(
      onTap: _loading ? null : _continueAsGuest,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Palette.kBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.kBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Palette.kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.explore_outlined,
                size: 16,
                color: Palette.kPrimary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Continuar como invitado',
              style: TextStyle(
                color: Palette.kPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _mode == LoginMode.cliente ? '¿No tienes cuenta? ' : '¿Tu empresa no tiene acceso? ',
          style: const TextStyle(color: Palette.kMuted, fontSize: 13),
        ),
        GestureDetector(
          onTap: () => context.push(
            _mode == LoginMode.cliente ? '/registro-cliente' : '/solicitud-empresa',
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
    );
  }
}

// ───────────── Segment pill
class _SegPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _SegPill({
    required this.icon,
    required this.text,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Palette.kAccent, Palette.kAccentLight],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: active ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Palette.kAccent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : Palette.kMuted,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: active ? Colors.white : Palette.kMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
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
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: Palette.kMuted, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        filled: true,
        fillColor: Palette.kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.kAccent, width: 1.8),
        ),
      ),
    );
  }
}
