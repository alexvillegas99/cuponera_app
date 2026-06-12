import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/session_flows.dart';
import 'package:enjoy/state/theme_controller.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:enjoy/widgets/account_switcher_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/profile_info.dart';
import '../../services/informacion_perfil_cliente_service.dart';
import '../../services/configuracion_service.dart';
import '../../utils/image_pick.dart';

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
  bool _uploadingPhoto = false;

  /// Controla la visibilidad de la opción "Eliminar cuenta" (config remota).
  /// Solo aparece cuando la clave `mostrar_eliminar_cuenta` = "true".
  bool _mostrarEliminar = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadConfigEliminar();
  }

  Future<void> _loadConfigEliminar() async {
    final valor =
        await ConfiguracionService.obtenerValor('mostrar_eliminar_cuenta');
    if (mounted) {
      setState(() => _mostrarEliminar = valor?.toLowerCase() == 'true');
    }
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

  /// Elige una foto (galería/cámara, con recorte) y la sube como avatar.
  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    final dataUrl = await pickAndCropImage();
    if (dataUrl == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      await authService.updateAvatar(dataUrl);
      if (!mounted) return;
      await _load(); // refresca el perfil con la nueva foto
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _data;

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Mi perfil'),
      body: RefreshIndicator(
        onRefresh: _load,
        color: context.ec.orange,
        backgroundColor: context.ec.glassStrong,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            if (_loading) _buildLoadingState(),
            if (!_loading && _error != null) _buildErrorCard(_error!),
            if (!_loading && _error == null && p != null) ...[
              // ── Hero header ─────────────────────────────────────
              _buildHeroHeader(p),
              const SizedBox(height: 12),

              // ── Stats ────────────────────────────────────────────
              _buildStats(p),
              const SizedBox(height: 18),

              // ── Preferencias ─────────────────────────────────────
              _buildPreferences(),
              const SizedBox(height: 18),

              // ── Cambiar de cuenta (multi-cuenta + biometría) ─────
              const AccountSwitcherSection(),

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
    final ec = context.ec;
    final displayName = p.name.isEmpty ? 'Invitado' : p.name;

    return GlassCard(
      accent: true,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _changePhoto,
            child: SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: EnjoyAvatar(
                      displayName,
                      size: 76,
                      imageUrl: p.avatarUrl,
                    ),
                  ),
                  if (_uploadingPhoto)
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black54,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: ec.accentGradient,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: ec.surfaceTop, width: 2),
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          size: 14, color: ec.onAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EnjoyTheme.heading(
                size: 19, weight: FontWeight.w800, color: ec.text),
          ),
          if (p.email.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              p.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EnjoyTheme.body(size: 13, color: ec.textSoft),
            ),
          ],
          const SizedBox(height: 16),
          EnjoyButton(
            label: 'Editar perfil',
            icon: Icons.edit_rounded,
            variant: EnjoyButtonVariant.ghost,
            expand: false,
            dense: true,
            onPressed: () => context.push('/perfil/editar'),
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
          child: StatCard(
            value: '${p.cuponeras}',
            label: 'Membresías',
            accent: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            value: '${p.favoritos}',
            label: 'Favoritos',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            value: '${p.escaneos}',
            label: 'Escaneos',
          ),
        ),
      ],
    );
  }

  // ── Preferencias (tema) ────────────────────────────────────────────
  Widget _buildPreferences() {
    final theme = context.watch<ThemeController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Apariencia'),
        ListRowTile(
          leading: IconBox(
            theme.isDark
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
          ),
          title: 'Tema oscuro',
          subtitle: theme.isDark ? 'Activado' : 'Desactivado',
          trailing: EnjoyToggle(
            value: theme.isDark,
            onChanged: (_) => context.read<ThemeController>().toggle(),
          ),
        ),
      ],
    );
  }

  // ── Account card ───────────────────────────────────────────────────
  Widget _buildAccountCard(ProfileInfo p) {
    final ec = context.ec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Cuenta'),
        ListRowTile(
          leading: const IconBox(Icons.notifications_outlined),
          title: 'Notificaciones',
          subtitle: 'Promociones y alertas',
          trailing:
              Icon(Icons.chevron_right_rounded, color: ec.textMute, size: 20),
          onTap: () => context.push('/perfil/notificaciones'),
        ),
        const SizedBox(height: 10),
        ListRowTile(
          leading: IconBox(Icons.logout_rounded, color: ec.red),
          title: 'Cerrar sesión',
          subtitle: 'Salir de tu cuenta',
          titleColor: ec.red,
          borderColor: ec.red.withValues(alpha: .3),
          onTap: () => SessionFlows.confirmLogout(context),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final ec = context.ec;
    // Paso 1: bottom sheet informativo
    final paso1 = await _showConfirmSheet(
      context,
      title: '¿Eliminar tu cuenta?',
      message:
          'Perderás acceso a tu historial, membresías y datos guardados. Podrás crear una cuenta nueva con el mismo correo si cambias de opinión.',
      confirmLabel: 'Continuar',
      icon: Icons.no_accounts_rounded,
    );
    if (paso1 != true || !mounted) return;

    // Paso 2: diálogo de confirmación final
    final paso2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dc = ctx.ec;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: dc.surfaceTop,
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dc.red.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delete_forever_rounded, color: dc.red, size: 28),
          ),
          title: Text(
            'Confirmación final',
            textAlign: TextAlign.center,
            style: EnjoyTheme.heading(
                size: 16, weight: FontWeight.w800, color: dc.text),
          ),
          content: Text(
            '¿Confirmas que deseas eliminar permanentemente tu cuenta? Esta acción no se puede deshacer.',
            textAlign: TextAlign.center,
            style: EnjoyTheme.body(size: 13, color: dc.textSoft),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            EnjoyButton(
              label: 'Sí, eliminar mi cuenta',
              variant: EnjoyButtonVariant.red,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
            EnjoyButton(
              label: 'Cancelar',
              variant: EnjoyButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        );
      },
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
          backgroundColor: ec.red,
        ),
      );
    }
  }

  // ── Danger zone ───────────────────────────────────────────────────
  Widget _buildDangerZone() {
    // Solo se muestra si la configuración remota lo habilita.
    if (!_mostrarEliminar) return const SizedBox.shrink();
    final ec = context.ec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel('Zona de peligro', padding: const EdgeInsets.only(bottom: 9)),
        ListRowTile(
          leading: IconBox(Icons.no_accounts_rounded, color: ec.red),
          title: 'Eliminar cuenta',
          subtitle: 'Acción permanente e irreversible',
          titleColor: ec.red,
          borderColor: ec.red.withValues(alpha: .3),
          trailing:
              Icon(Icons.chevron_right_rounded, color: ec.red, size: 20),
          onTap: _confirmDeleteAccount,
        ),
      ],
    );
  }

  // ── Loading ────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    final ec = context.ec;
    return GlassCard(
      child: SizedBox(
        height: 130,
        child: Center(
          child: CircularProgressIndicator(color: ec.orange, strokeWidth: 2),
        ),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────
  Widget _buildErrorCard(String msg) {
    final ec = context.ec;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ec.red.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, color: ec.red),
          ),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: EnjoyTheme.body(
                size: 14, weight: FontWeight.w600, color: ec.text),
          ),
          const SizedBox(height: 14),
          EnjoyButton(
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            variant: EnjoyButtonVariant.ghost,
            expand: false,
            dense: true,
            onPressed: _load,
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
    final ec = context.ec;
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: ec.surfaceTop,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final sc = ctx.ec;
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
                  color: sc.stroke,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBox(icon, color: sc.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: EnjoyTheme.heading(
                              size: 17,
                              weight: FontWeight.w800,
                              color: sc.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: EnjoyTheme.body(size: 13, color: sc.textSoft),
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
                    child: EnjoyButton(
                      label: cancelLabel,
                      variant: EnjoyButtonVariant.ghost,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: EnjoyButton(
                      label: confirmLabel,
                      variant: EnjoyButtonVariant.red,
                      onPressed: () => Navigator.pop(ctx, true),
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
