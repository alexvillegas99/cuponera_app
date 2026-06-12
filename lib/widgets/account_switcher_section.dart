import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/biometric_service.dart';
import 'package:enjoy/services/session_flows.dart';
import 'package:enjoy/ui/enjoy.dart';

/// Sección "Mis cuentas" del Perfil. Muestra:
/// - las cuentas guardadas (cambiar entre ellas con biometría),
/// - la cuenta "hermana" del mismo correo (cliente↔empresa) si aún no está
///   guardada (se cambia con `/auth/switch`),
/// - opción para agregar otra cuenta.
/// Funciona en ambos lados (cliente y empresa: admin, admin-local, staff).
class AccountSwitcherSection extends StatefulWidget {
  /// Si es false (p.ej. dashboard admin), NO muestra "Agregar otra cuenta" y
  /// oculta toda la sección cuando no hay otra cuenta a la que cambiar.
  final bool showAdd;
  const AccountSwitcherSection({super.key, this.showAdd = true});

  @override
  State<AccountSwitcherSection> createState() => _AccountSwitcherSectionState();
}

class _AccountSwitcherSectionState extends State<AccountSwitcherSection> {
  final _auth = AuthService();
  bool _loading = true;
  bool _bioReady = false;

  List<SavedAccount> _saved = [];
  String? _currentId;

  bool _showSiblingSwitch = false;
  String _siblingLabel = ''; // 'empresa' | 'cliente'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _auth.getUser();
    final email = (user?['correo'] ?? user?['email'] ?? '').toString();
    final kind = (user?['kind'] ?? 'USUARIO').toString().toUpperCase();

    final saved = await _auth.listAccounts();
    final currentId = await _auth.currentAccountId();
    final bio = await BiometricService.isReady();

    // ¿La cuenta hermana (otro tipo, mismo correo) existe y NO está guardada?
    bool showSibling = false;
    String siblingLabel = '';
    final siblingKind = kind == 'CLIENTE' ? 'USUARIO' : 'CLIENTE';
    final siblingSaved = saved.any((a) =>
        a.email.toLowerCase() == email.toLowerCase() &&
        a.kind.toUpperCase() == siblingKind);
    if (email.isNotEmpty && !siblingSaved) {
      try {
        final types = await _auth.checkAccountTypes(email);
        final exists = siblingKind == 'USUARIO' ? types.usuario : types.cliente;
        if (exists) {
          showSibling = true;
          siblingLabel = siblingKind == 'USUARIO' ? 'empresa' : 'cliente';
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _saved = saved;
      _currentId = currentId;
      _bioReady = bio;
      _showSiblingSwitch = showSibling;
      _siblingLabel = siblingLabel;
      _loading = false;
    });
  }

  Future<void> _addAccount() async {
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    if (_loading) return const SizedBox.shrink();

    final others = _saved.where((a) => a.id != _currentId).toList();
    final hayAdicionales = others.isNotEmpty || _showSiblingSwitch;

    // Si no hay otra cuenta a la que cambiar y no se permite agregar, no
    // mostramos nada (ej. dashboard admin sin cuenta de cliente asociada).
    if (!hayAdicionales && !widget.showAdd) return const SizedBox.shrink();

    final extra = others.length + (_showSiblingSwitch ? 1 : 0);
    final subtitle = _showSiblingSwitch
        ? 'Cambiar a ${_siblingLabel == 'empresa' ? 'empresa' : 'cliente'}'
            '${others.isNotEmpty ? ' y más' : ''}'
        : extra > 0
            ? 'Tienes $extra cuenta${extra == 1 ? '' : 's'} adicional${extra == 1 ? '' : 'es'}'
            : 'Agregar o cambiar de cuenta';

    // Item compacto → abre un modal con las cuentas (ahorra espacio).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListRowTile(
          leading: const IconBox(Icons.swap_horiz_rounded),
          title: 'Mis cuentas',
          subtitle: subtitle,
          trailing:
              Icon(Icons.chevron_right_rounded, color: ec.textMute, size: 20),
          onTap: _openModal,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _openModal() {
    final ec = context.ec;
    final others = _saved.where((a) => a.id != _currentId).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: ec.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
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
              const SizedBox(height: 14),
              Text('Mis cuentas',
                  style: EnjoyTheme.heading(
                      size: 18, weight: FontWeight.w800, color: ec.text)),
              const SizedBox(height: 4),
              Text('Cambia entre tus cuentas con huella o Face ID.',
                  style: EnjoyTheme.body(size: 13, color: ec.textSoft)),
              const SizedBox(height: 14),

              if (_showSiblingSwitch)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListRowTile(
                    leading: IconBox(
                      _siblingLabel == 'empresa'
                          ? Icons.storefront_rounded
                          : Icons.person_rounded,
                      accent: _siblingLabel == 'cliente',
                    ),
                    title:
                        'Cambiar a ${_siblingLabel == 'empresa' ? 'Empresa' : 'Cliente'}',
                    subtitle: 'Misma cuenta · huella / Face ID',
                    trailing: Icon(Icons.fingerprint_rounded,
                        color: ec.orangeSoft, size: 22),
                    onTap: () {
                      Navigator.pop(ctx);
                      SessionFlows.switchToSibling(context);
                    },
                  ),
                ),

              ...others.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListRowTile(
                      leading: EnjoyAvatar(a.displayName,
                          size: 40, accent: a.isCliente),
                      title: a.displayName,
                      subtitle: 'Cuenta ${a.tipoLabel} · huella / Face ID',
                      trailing: Icon(Icons.fingerprint_rounded,
                          color: ec.orangeSoft, size: 22),
                      onTap: () {
                        Navigator.pop(ctx);
                        SessionFlows.switchAccount(context, a);
                      },
                    ),
                  )),

              if (!_bioReady)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
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
                            'Activa la huella o el Face ID de tu teléfono para '
                            'cambiar de cuenta de forma rápida y segura.',
                            style:
                                EnjoyTheme.body(size: 12.5, color: ec.textSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (widget.showAdd)
                ListRowTile(
                  leading: const IconBox(Icons.person_add_alt_1_rounded),
                  title: 'Agregar otra cuenta',
                  subtitle: 'Inicia sesión con otra cuenta',
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: ec.textMute, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addAccount();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
