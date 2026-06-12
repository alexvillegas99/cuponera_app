import 'dart:io';

import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum LoginMode { cliente, empresa }

enum _LoginStep { email, password }

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

  _LoginStep _step = _LoginStep.email;
  LoginMode _mode = LoginMode.cliente;
  bool _obscure = true;
  bool _loading = false;
  bool _checkingEmail = false;
  bool _googleLoading = false;
  bool _appleLoading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
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

  bool _validEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());

  // ── Paso 1: continuar con el correo ──
  Future<void> _continueEmail() async {
    final email = _userCtrl.text.trim();
    if (!_validEmail(email)) {
      _snack('Ingresa un correo válido.');
      return;
    }
    setState(() => _checkingEmail = true);
    try {
      final types = await _auth.checkAccountTypes(email);
      if (!mounted) return;
      if (!types.cliente && !types.usuario) {
        _snack('No encontramos una cuenta con ese correo. Regístrate o usa otro.');
        return;
      }
      LoginMode? mode;
      if (types.cliente && types.usuario) {
        mode = await _chooseTypeSheet();
        if (mode == null) return; // canceló
      } else {
        mode = types.cliente ? LoginMode.cliente : LoginMode.empresa;
      }
      setState(() {
        _mode = mode!;
        _step = _LoginStep.password;
      });
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _checkingEmail = false);
    }
  }

  void _backToEmail() {
    setState(() {
      _step = _LoginStep.email;
      _passCtrl.clear();
      _obscure = true;
    });
  }

  // ── Modal: ¿cómo quieres ingresar? ──
  Future<LoginMode?> _chooseTypeSheet() {
    final ec = context.ec;
    return showModalBottomSheet<LoginMode>(
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
              Text('¿Cómo quieres ingresar?',
                  style: EnjoyTheme.heading(
                      size: 18, weight: FontWeight.w800, color: ec.text)),
              const SizedBox(height: 4),
              Text('Este correo tiene cuenta de cliente y de empresa.',
                  style: EnjoyTheme.body(size: 13, color: ec.textSoft)),
              const SizedBox(height: 16),
              ListRowTile(
                leading: const IconBox(Icons.person_rounded, accent: true),
                title: 'Como cliente',
                subtitle: 'Tus membresías y promociones',
                trailing: Icon(Icons.chevron_right_rounded, color: ec.textMute),
                onTap: () => Navigator.pop(ctx, LoginMode.cliente),
              ),
              const SizedBox(height: 10),
              ListRowTile(
                leading: const IconBox(Icons.storefront_rounded),
                title: 'Como empresa',
                subtitle: 'Panel de gestión del negocio',
                trailing: Icon(Icons.chevron_right_rounded, color: ec.textMute),
                onTap: () => Navigator.pop(ctx, LoginMode.empresa),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Login con clave (paso 2) ──
  Future<void> _doLogin() async {
    if (_passCtrl.text.isEmpty) {
      _snack('Ingresa tu contraseña.');
      return;
    }
    setState(() => _loading = true);
    try {
      _mode == LoginMode.cliente
          ? await _auth.loginCliente(_userCtrl.text.trim(), _passCtrl.text, context)
          : await _auth.loginEmpresa(_userCtrl.text.trim(), _passCtrl.text, context);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _snack(msg.isEmpty ? 'Credenciales inválidas. Inténtalo nuevamente.' : msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    await _auth.continueAsGuest();
    if (mounted) context.go('/home_guest');
  }

  // ── Social Google: autentica → valida tipos por correo → entra ──
  Future<void> _socialGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final g = await _auth.googleSignIn();
      if (g.idToken == null) return; // cancelado
      LoginMode mode = LoginMode.cliente;
      final email = g.email;
      if (email != null && email.isNotEmpty) {
        final types = await _auth.checkAccountTypes(email);
        if (types.cliente && types.usuario) {
          final m = await _chooseSocialTypeSheet();
          if (m == null) return; // canceló el modal
          mode = m;
        } else if (types.usuario) {
          mode = LoginMode.empresa;
        } else {
          mode = LoginMode.cliente; // existente o nuevo → registro
        }
      }
      if (!mounted) return;
      setState(() => _mode = mode);
      if (mode == LoginMode.cliente) {
        final result =
            await _auth.loginClienteWithGoogle(context, idToken: g.idToken);
        if (result['registered'] == false && mounted) {
          context.push('/registro-cliente', extra: result);
        }
      } else {
        await _auth.loginUsuarioWithGoogle(context, idToken: g.idToken);
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _socialApple() async {
    final mode = await _chooseSocialTypeSheet();
    if (mode == null || !mounted) return;
    setState(() => _mode = mode);
    await _doAppleLogin();
  }

  Future<LoginMode?> _chooseSocialTypeSheet() {
    final ec = context.ec;
    return showModalBottomSheet<LoginMode>(
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
              Text('¿Cómo quieres ingresar?',
                  style: EnjoyTheme.heading(
                      size: 18, weight: FontWeight.w800, color: ec.text)),
              const SizedBox(height: 4),
              Text('Elige el tipo de cuenta para continuar.',
                  style: EnjoyTheme.body(size: 13, color: ec.textSoft)),
              const SizedBox(height: 16),
              ListRowTile(
                leading: const IconBox(Icons.person_rounded, accent: true),
                title: 'Como cliente',
                subtitle: 'Tus membresías y promociones',
                trailing: Icon(Icons.chevron_right_rounded, color: ec.textMute),
                onTap: () => Navigator.pop(ctx, LoginMode.cliente),
              ),
              const SizedBox(height: 10),
              ListRowTile(
                leading: const IconBox(Icons.storefront_rounded),
                title: 'Como empresa',
                subtitle: 'Panel de gestión del negocio',
                trailing: Icon(Icons.chevron_right_rounded, color: ec.textMute),
                onTap: () => Navigator.pop(ctx, LoginMode.empresa),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doAppleLogin() async {
    setState(() => _appleLoading = true);
    try {
      if (_mode == LoginMode.cliente) {
        final result = await _auth.loginClienteWithApple(context);
        if (result['registered'] == false && mounted) {
          context.push('/registro-cliente', extra: result);
        }
      } else {
        await _auth.loginUsuarioWithApple(context);
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    // Si llegamos a /login desde /cuentas (push), mostramos un BackChip
    // para que el usuario pueda volver a sus cuentas guardadas.
    final puedeVolver = Navigator.of(context).canPop();
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: puedeVolver ? const EnjoyAppBar() : null,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _step == _LoginStep.email
                    ? _buildEmailStep(ec)
                    : _buildPasswordStep(ec),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── PASO 1: CORREO ─────────────────────────
  Widget _buildEmailStep(EnjoyColors ec) {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _buildLogo(ec)),
        const SizedBox(height: 26),
        Text('Bienvenido',
            style: EnjoyTheme.heading(
                size: 28, weight: FontWeight.w800, color: ec.text, height: 1.1)),
        const SizedBox(height: 6),
        Text('Ingresa tu correo para continuar',
            style: EnjoyTheme.body(size: 14, color: ec.textSoft)),
        const SizedBox(height: 26),
        const FieldLabel('Correo electrónico'),
        _Field(
          controller: _userCtrl,
          hint: 'tucorreo@ejemplo.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _continueEmail(),
        ),
        const SizedBox(height: 22),
        EnjoyButton(
          label: 'Continuar',
          trailingIcon: Icons.arrow_forward_rounded,
          loading: _checkingEmail,
          onPressed: _continueEmail,
        ),
        const SizedBox(height: 16),
        _divider(ec),
        const SizedBox(height: 16),
        _buildGoogleBtn(ec),
        if (Platform.isIOS) ...[
          const SizedBox(height: 10),
          _buildAppleBtn(ec),
        ],
        const SizedBox(height: 12),
        _buildGuestBtn(ec),
        const SizedBox(height: 22),
        _buildFooter(ec),
      ],
    );
  }

  // ───────────────────────── PASO 2: CLAVE ─────────────────────────
  Widget _buildPasswordStep(EnjoyColors ec) {
    final isCliente = _mode == LoginMode.cliente;
    return Column(
      key: const ValueKey('password'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _buildLogo(ec)),
        const SizedBox(height: 24),
        // Correo + tipo elegido (editable volviendo atrás)
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconBox(isCliente ? Icons.person_rounded : Icons.storefront_rounded,
                  accent: isCliente, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_userCtrl.text.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EnjoyTheme.heading(size: 14, color: ec.text)),
                    const SizedBox(height: 3),
                    Pill(isCliente ? 'Cliente' : 'Empresa',
                        variant:
                            isCliente ? PillVariant.orange : PillVariant.blue,
                        dense: true),
                  ],
                ),
              ),
              TextButton(
                onPressed: _backToEmail,
                child: Text('Cambiar',
                    style: EnjoyTheme.body(
                        size: 13, weight: FontWeight.w600, color: ec.orangeSoft)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Hola de nuevo',
            style: EnjoyTheme.heading(
                size: 24, weight: FontWeight.w800, color: ec.text, height: 1.1)),
        const SizedBox(height: 6),
        Text('Ingresa tu contraseña para continuar',
            style: EnjoyTheme.body(size: 14, color: ec.textSoft)),
        const SizedBox(height: 22),
        const FieldLabel('Contraseña'),
        _Field(
          controller: _passCtrl,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure,
          autofocus: true,
          onSubmitted: (_) => _doLogin(),
          suffix: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: ec.textMute,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => context.push('/recuperar',
                extra: _mode == LoginMode.empresa),
            child: Text('¿Olvidaste tu contraseña?',
                style: EnjoyTheme.body(
                    size: 13, weight: FontWeight.w600, color: ec.orangeSoft)),
          ),
        ),
        const SizedBox(height: 22),
        EnjoyButton(
          label: 'Iniciar sesión',
          icon: Icons.login_rounded,
          loading: _loading,
          onPressed: _doLogin,
        ),
      ],
    );
  }

  Widget _divider(EnjoyColors ec) => Row(
        children: [
          Expanded(child: Divider(color: ec.stroke, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('o continúa con',
                style: EnjoyTheme.body(size: 12, color: ec.textMute)),
          ),
          Expanded(child: Divider(color: ec.stroke, thickness: 1)),
        ],
      );

  Widget _buildLogo(EnjoyColors ec) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        gradient: ec.accentGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: ec.orange.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Image.asset('assets/img/splash.png', fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildGoogleBtn(EnjoyColors ec) {
    return GestureDetector(
      onTap: (_loading || _googleLoading) ? null : _socialGoogle,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: ec.glassStrong,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: ec.strokeStrong),
        ),
        child: Center(
          child: _googleLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: ec.orange),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/img/google_logo.webp',
                        width: 22, height: 22),
                    const SizedBox(width: 10),
                    Text('Continuar con Google',
                        style: EnjoyTheme.body(
                            size: 14, weight: FontWeight.w600, color: ec.text)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAppleBtn(EnjoyColors ec) {
    return GestureDetector(
      onTap: (_loading || _appleLoading) ? null : _socialApple,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: ec.isDark ? Colors.black : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: ec.stroke),
        ),
        child: Center(
          child: _appleLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apple, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text('Continuar con Apple',
                        style: EnjoyTheme.body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGuestBtn(EnjoyColors ec) {
    return GestureDetector(
      onTap: _loading ? null : _continueAsGuest,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: ec.glass,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: ec.stroke),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: ec.orange.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.explore_outlined, size: 16, color: ec.orangeSoft),
            ),
            const SizedBox(width: 10),
            Text('Continuar como invitado',
                style: EnjoyTheme.body(
                    size: 14, weight: FontWeight.w600, color: ec.text)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(EnjoyColors ec) {
    return Column(
      children: [
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('¿No tienes cuenta? ',
                  style: EnjoyTheme.body(size: 13, color: ec.textMute)),
              GestureDetector(
                onTap: () => context.push('/registro-cliente'),
                child: Text('Regístrate',
                    style: EnjoyTheme.body(
                        size: 13, weight: FontWeight.w700, color: ec.orangeSoft)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: GestureDetector(
            onTap: () => context.push('/solicitud-empresa'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined,
                    size: 13, color: ec.textMute.withValues(alpha: 0.8)),
                const SizedBox(width: 5),
                Text('¿Empresa nueva? Solicitar acceso',
                    style: EnjoyTheme.body(
                        size: 12,
                        weight: FontWeight.w500,
                        color: ec.textMute.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────── Input field con ícono prefijo (interno de login)
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final bool autofocus;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.autofocus = false,
    this.suffix,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return TextField(
      controller: controller,
      obscureText: obscure,
      autofocus: autofocus,
      keyboardType: keyboardType,
      cursorColor: ec.orange,
      onSubmitted: onSubmitted,
      textInputAction:
          onSubmitted != null ? TextInputAction.go : TextInputAction.next,
      style: EnjoyTheme.body(size: 14, color: ec.text),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: ec.orangeSoft, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
      ),
    );
  }
}
