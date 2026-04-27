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
      setState(() => _data = info);
    } catch (_) {
      setState(() => _error = 'No se pudo cargar tu perfil');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = _data;

    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Palette.kPrimary,
        title: const Text(
          'Mi perfil',
          style: TextStyle(
            color: Palette.kTitle,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Palette.kSurface,
            border: Border(bottom: BorderSide(color: Palette.kBorder, width: 1)),
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _load,
        color: Palette.kAccent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_loading) _buildLoadingState(),
            if (!_loading && _error != null) _buildErrorCard(_error!),
            if (!_loading && _error == null && p != null) ...[

              // ── Hero header ─────────────────────────────────────
              _buildHeroHeader(p),

              const SizedBox(height: 12),

              // ── Stats ────────────────────────────────────────────
              _buildStats(p),

              const SizedBox(height: 12),

              // ── Ciudades ─────────────────────────────────────────
              _buildSection(
                icon: Icons.location_on_outlined,
                iconColor: Palette.kPrimary,
                title: 'Mis ciudades',
                child: p.ciudades.isEmpty
                    ? const Text(
                        'Aún no configuras ciudades',
                        style: TextStyle(color: Palette.kMuted, fontSize: 13),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final c in p.ciudades) _Chip(c)],
                      ),
              ),

              const SizedBox(height: 12),

              // ── Categorías ───────────────────────────────────────
              _buildSection(
                icon: Icons.category_outlined,
                iconColor: Palette.kAccent,
                title: 'Categorías favoritas',
                child: p.categoriasFav.isEmpty
                    ? const Text(
                        'Aún no seleccionas categorías',
                        style: TextStyle(color: Palette.kMuted, fontSize: 13),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final t in p.categoriasFav) _Chip(t)],
                      ),
              ),

              const SizedBox(height: 12),

              // ── Cuenta ───────────────────────────────────────────
              _buildAccountCard(p),

              const SizedBox(height: 24),

              // ── Zona peligrosa ───────────────────────────────────
              _buildDangerZone(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Hero header ────────────────────────────────────────────────────
  Widget _buildHeroHeader(ProfileInfo p) {
    final initials = _initials(p.name.isEmpty ? 'U' : p.name);
    final displayName = p.name.isEmpty ? 'Invitado' : p.name;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Palette.kAccent, Palette.kAccentLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Palette.kAccent.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Nombre
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Palette.kTitle,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),

          if (p.email != null && p.email!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              p.email!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Palette.kMuted, fontSize: 13),
            ),
          ],

          const SizedBox(height: 16),

          // Botón editar
          GestureDetector(
            onTap: () => context.push('/perfil/editar'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.kAccent, Palette.kAccentLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Palette.kAccent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Editar perfil',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats ──────────────────────────────────────────────────────────
  Widget _buildStats(ProfileInfo p) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
            value: p.favoritos,
            label: 'Favoritos',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.qr_code_2_rounded,
            iconColor: Palette.kPrimary,
            value: p.cuponeras,
            label: 'Cuponeras',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.history_rounded,
            iconColor: Palette.kAccent,
            value: p.escaneos,
            label: 'Escaneos',
          ),
        ),
      ],
    );
  }

  // ── Section card ───────────────────────────────────────────────────
  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Palette.kTitle,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ── Account card ───────────────────────────────────────────────────
  Widget _buildAccountCard(ProfileInfo p) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _SettingTile(
            icon: Icons.person_outline_rounded,
            iconColor: Palette.kPrimary,
            title: 'Editar perfil',
            subtitle: 'Nombre y correo',
            onTap: () => context.push('/perfil/editar'),
          ),
          const Divider(height: 1, color: Palette.kBorder, indent: 56),
          _SettingTile(
            icon: Icons.notifications_outlined,
            iconColor: Palette.kAccent,
            title: 'Notificaciones',
            subtitle: 'Promociones y alertas',
            onTap: () => context.push('/perfil/notificaciones'),
          ),
          const Divider(height: 1, color: Palette.kBorder, indent: 56),
          _SettingTile(
            icon: Icons.logout_rounded,
            iconColor: Colors.redAccent,
            title: 'Cerrar sesión',
            subtitle: 'Salir de tu cuenta',
            danger: true,
            onTap: () async {
              final ok = await _showConfirmSheet(
                context,
                title: '¿Cerrar sesión?',
                message: 'Se cerrará tu sesión en esta aplicación.',
                confirmLabel: 'Cerrar sesión',
                icon: Icons.logout_rounded,
              );
              if (ok == true) {
                await authService.logout();
                if (mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    // Paso 1: bottom sheet informativo
    final paso1 = await _showConfirmSheet(
      context,
      title: '¿Eliminar tu cuenta?',
      message:
          'Perderás acceso a tu historial, cuponeras y datos guardados. Podrás crear una cuenta nueva con el mismo correo si cambias de opinión.',
      confirmLabel: 'Continuar',
      icon: Icons.no_accounts_rounded,
    );
    if (paso1 != true || !mounted) return;

    // Paso 2: diálogo de confirmación final
    final paso2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.delete_forever_rounded, color: Colors.red.shade700, size: 28),
        ),
        title: const Text(
          'Confirmación final',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          '¿Confirmas que deseas eliminar permanentemente tu cuenta? Esta acción no se puede deshacer.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Sí, eliminar mi cuenta', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Palette.kBorder),
                foregroundColor: Palette.kMuted,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
    if (paso2 != true || !mounted) return;

    try {
      await authService.deleteAccount();
      if (mounted) context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Danger zone ───────────────────────────────────────────────────
  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Zona de peligro',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade100, width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _confirmDeleteAccount(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.no_accounts_rounded, color: Colors.red.shade700, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Eliminar cuenta',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Acción permanente e irreversible',
                            style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.red.shade300, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Loading ────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(color: Palette.kAccent, strokeWidth: 2),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────
  Widget _buildErrorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.redAccent),
          ),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: Palette.kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(
                  color: Palette.kAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirm bottom sheet ───────────────────────────────────────────
  Future<bool?> _showConfirmSheet(
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
                margin: const EdgeInsets.only(bottom: 16),
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
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.redAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Palette.kTitle,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: const TextStyle(color: Palette.kMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Palette.kBorder),
                        foregroundColor: Palette.kMuted,
                        padding: const EdgeInsets.symmetric(vertical: 13),
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
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
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
}

// ── Stat card ──────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Palette.kMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Chip ───────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.kAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.kAccent.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Palette.kAccent,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ── Setting tile ───────────────────────────────────────────────────────
class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: danger ? Colors.redAccent : Palette.kTitle,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: danger
                            ? Colors.redAccent.withOpacity(0.7)
                            : Palette.kMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!danger)
              Icon(Icons.chevron_right_rounded, color: Palette.kMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
