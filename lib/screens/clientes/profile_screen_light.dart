// lib/screens/profile/profile_screen_light.dart
import 'package:enjoy/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../ui/palette.dart';
import '../../models/profile_info.dart';
import '../../services/informacion_perfil_cliente_service.dart';

class ProfileScreenLight extends StatefulWidget {
  const ProfileScreenLight({super.key});

  @override
  State<ProfileScreenLight> createState() => _ProfileScreenLightState();
}

class _ProfileScreenLightState extends State<ProfileScreenLight> {
  final authService = AuthService();
  final _svc = InformacionPerfilClienteService();

  ProfileInfo? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await _svc.fetch();
      setState(() {
        _data = info;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar tu perfil';
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<void> _refresh() => _load();

  String _greeting(ProfileInfo? p) {
    final n = p?.name.trim();
    if (n == null || n.isEmpty) return '¡Bienvenido!';
    final first = n.split(' ').first;
    return '¡Hola, $first! 👋';
    // Si prefieres: return '¡Bienvenido, $first!';
  }

  @override
  Widget build(BuildContext context) {
    final p = _data;

    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        title: const Text('Mi perfil'),
        backgroundColor: Palette.kAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: RefreshIndicator(
        onRefresh: _refresh,
        color: Palette.kAccent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            if (_loading) _loadingShimmer(),
            if (!_loading && _error != null)
              _errorCard(_error!, onRetry: _load),
            if (!_loading && _error == null && p != null) ...[
              // ===== Header (saludo + nombre+email) =====
              // ===== Header (saludo + nombre+email) =====
              _HeroHeader(
                greeting: _greeting(p),
                name: p.name.isEmpty ? 'Invitado' : p.name,
                email: p.email,
                onEdit: () => context.push('/perfil/editar'),
              ),

              const SizedBox(height: 12),

              // ===== Stats =====
              Container(
                decoration: _cardBox(),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Favoritos',
                        value: p.favoritos,
                        icon: Icons.favorite,
                      ),
                    ),
                    _vDivider(),
                    Expanded(
                      child: _StatTile(
                        label: 'Cuponeras',
                        value: p.cuponeras,
                        icon: Icons.qr_code_2,
                      ),
                    ),
                    _vDivider(),
                    Expanded(
                      child: _StatTile(
                        label: 'Escaneos',
                        value: p.escaneos,
                        icon: Icons.history,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== Ciudades preferidas =====
              Container(
                decoration: _cardBox(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(Icons.location_on_outlined, 'Mis ciudades'),
                    const SizedBox(height: 10),
                    if (p.ciudades.isEmpty)
                      const Text(
                        'Aún no configuras ciudades',
                        style: TextStyle(color: Palette.kMuted),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: -6,
                        children: [for (final c in p.ciudades) _Chip(c)],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== Categorías favoritas =====
              Container(
                decoration: _cardBox(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                      Icons.category_outlined,
                      'Categorías favoritas',
                    ),
                    const SizedBox(height: 10),
                    if (p.categoriasFav.isEmpty)
                      const Text(
                        'Aún no seleccionas categorías',
                        style: TextStyle(color: Palette.kMuted),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: -6,
                        children: [for (final t in p.categoriasFav) _Chip(t)],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== Cuenta =====
              Container(
                decoration: _cardBox(),
                child: Column(
                  children: [
                    _SettingTile(
                      icon: Icons.person_outline,
                      title: 'Editar perfil',
                      subtitle: 'Nombre y correo',
                      onTap: () => context.push('/perfil/editar'),
                    ),
                    _divider(),
                    _SettingTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notificaciones',
                      subtitle: 'Promociones y alertas',
                      onTap: () => context.push('/perfil/notificaciones'),
                    ),
                    _divider(),
                    _SettingTile(
                      icon: Icons.logout,
                      title: 'Cerrar sesión',
                      subtitle: 'Salir de tu cuenta',
                      danger: true,
                      onTap: () async {
                        final confirmar = await showConfirmBottomSheet(
                          context,
                          title: '¿Cerrar sesión?',
                          message: 'Se cerrará tu sesión en esta aplicación.',
                          confirmLabel: 'Cerrar sesión',
                          cancelLabel: 'Cancelar',
                          icon: Icons.logout,
                        );
                        if (confirmar == true) {
                          await authService.logout();
                          if (context.mounted) context.go('/login');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool?> showConfirmBottomSheet(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    IconData icon = Icons.logout,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withOpacity(0.25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Palette.kAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Palette.kPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Palette.kTitle,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message,
                  style: const TextStyle(color: Palette.kMuted),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Palette.kPrimary.withOpacity(0.25),
                        ),
                        foregroundColor: Palette.kPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ==== helpers UI ====
  Widget _loadingShimmer() {
    return Container(
      height: 140,
      decoration: _cardBox(),
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(
          color: Palette.kPrimary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _errorCard(String msg, {required VoidCallback onRetry}) {
    return Container(
      decoration: _cardBox(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(color: Palette.kTitle)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  BoxDecoration _cardBox() {
    return BoxDecoration(
      color: Palette.kSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Palette.kPrimary.withOpacity(0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Palette.kPrimary, size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Palette.kPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 38,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Palette.kBorder,
  );

  Widget _divider() => const Divider(height: 1, color: Palette.kBorder);
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Palette.kPrimary,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Palette.kPrimary, // resalta el número en azul
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Palette.kMuted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.kAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Palette.kPrimary.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Palette.kPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = danger
        ? Colors.redAccent.withOpacity(0.12)
        : Palette.kAccent.withOpacity(0.12);
    final iconColor = danger ? Colors.redAccent : Palette.kPrimary;
    final titleColor = danger ? Colors.redAccent : Palette.kPrimary;
    final sub = danger ? Colors.redAccent.shade200 : Palette.kMuted;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: iconBg,
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(color: sub))
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: danger ? Colors.redAccent : Palette.kPrimary.withOpacity(0.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final String? email;
  final VoidCallback onEdit;

  const _HeroHeader({
    required this.greeting,
    required this.name,
    required this.email,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.kPrimary.withOpacity(0.08)),
        gradient: const LinearGradient(
          colors: [Colors.white, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Palette.kPrimary.withOpacity(0.1),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
      
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.kAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Palette.kAccent == null
                      ? null
                      : const TextStyle(color: Palette.kAccent),
                ),
                if (email != null && email!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Palette.kAccent),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: Palette.kAccent),
          ),
        ],
      ),
    );
  }
}
