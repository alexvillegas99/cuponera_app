import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/biometric_service.dart';
import 'package:enjoy/services/session_flows.dart';
import 'package:enjoy/ui/enjoy.dart';

/// Selector de cuentas guardadas al abrir la app (estilo Facebook).
/// Cada cuenta se restaura con biometría.
class AccountPickerScreen extends StatefulWidget {
  const AccountPickerScreen({super.key});

  @override
  State<AccountPickerScreen> createState() => _AccountPickerScreenState();
}

class _AccountPickerScreenState extends State<AccountPickerScreen> {
  final _auth = AuthService();
  List<SavedAccount> _accounts = [];
  bool _loading = true;
  bool _bioReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await _auth.listAccounts();
    final bio = await BiometricService.isReady();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _bioReady = bio;
      _loading = false;
    });
    if (accounts.isEmpty && mounted) context.go('/login');
  }

  Future<void> _remove(SavedAccount acc) async {
    await _auth.removeAccount(acc.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ec.orange))
          : ListView(
              padding: const EdgeInsets.only(top: 28, bottom: 28),
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: ec.accentGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: ec.orange.withValues(alpha: .5),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child:
                        Image.asset('assets/img/splash.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Elige tu cuenta',
                    textAlign: TextAlign.center,
                    style: EnjoyTheme.heading(
                        size: 24, weight: FontWeight.w800, color: ec.text)),
                const SizedBox(height: 6),
                Text(
                  _bioReady
                      ? 'Entra rápido con tu huella o Face ID.'
                      : 'Activa la biometría de tu teléfono para entrar con un toque.',
                  textAlign: TextAlign.center,
                  style: EnjoyTheme.body(size: 14, color: ec.textSoft),
                ),
                const SizedBox(height: 24),
                for (final a in _accounts) ...[
                  _AccountCard(
                    acc: a,
                    onTap: () => SessionFlows.switchAccount(context, a),
                    onRemove: () => _confirmRemove(a),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_bioReady) ...[
                  GlassCard(
                    accent: true,
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.fingerprint_rounded,
                            size: 18, color: ec.orangeSoft),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Para desbloquear el ingreso rápido, activa la huella '
                            'o el Face ID en los ajustes de tu teléfono.',
                            style:
                                EnjoyTheme.body(size: 12.5, color: ec.textSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                EnjoyButton(
                  label: 'Usar otra cuenta',
                  icon: Icons.person_add_alt_1_rounded,
                  variant: EnjoyButtonVariant.ghost,
                  // `push` (no `go`) para apilar login sobre /cuentas y poder
                  // volver con el botón de atrás si se arrepiente.
                  onPressed: () => context.push('/login'),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmRemove(SavedAccount acc) async {
    final ec = context.ec;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: ec.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Quitar cuenta guardada',
                  style: EnjoyTheme.heading(
                      size: 16, weight: FontWeight.w800, color: ec.text)),
              const SizedBox(height: 8),
              Text(
                'Se quitará ${acc.displayName} (${acc.tipoLabel}) de este '
                'dispositivo. Podrás volver a iniciar sesión cuando quieras.',
                textAlign: TextAlign.center,
                style: EnjoyTheme.body(size: 13, color: ec.textSoft),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: EnjoyButton(
                    label: 'Cancelar',
                    variant: EnjoyButtonVariant.ghost,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EnjoyButton(
                    label: 'Quitar',
                    variant: EnjoyButtonVariant.red,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await _remove(acc);
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.acc,
    required this.onTap,
    required this.onRemove,
  });
  final SavedAccount acc;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          EnjoyAvatar(acc.displayName, size: 48, accent: acc.isCliente),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(acc.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EnjoyTheme.heading(size: 15, color: ec.text)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Pill(acc.tipoLabel,
                        variant: acc.isCliente
                            ? PillVariant.orange
                            : PillVariant.blue,
                        dense: true),
                    if (acc.email.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(acc.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                EnjoyTheme.body(size: 12, color: ec.textMute)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.fingerprint_rounded, color: ec.orangeSoft, size: 22),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.close_rounded, size: 18, color: ec.textMute),
            ),
          ),
        ],
      ),
    );
  }
}
