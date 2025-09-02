import 'package:flutter/material.dart';
import '../../ui/palette.dart';

class ProfileScreenLight extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;

  /// Counters
  final int favoritos;
  final int cuponeras;
  final int escaneos;

  /// Preferencias
  final List<String> ciudades;
  final List<String> categoriasFav;

  const ProfileScreenLight({
    super.key,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.favoritos = 0,
    this.cuponeras = 0,
    this.escaneos = 0,
    this.ciudades = const [],
    this.categoriasFav = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        title: const Text('Mi perfil'),
        backgroundColor: Palette.kSurface,
        foregroundColor: Palette.kTitle,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // ===== Header =====
          Container(
            decoration: _cardBox(),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFE9E5FF),
                  backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Color(0xFF7C6CF4), size: 32)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Palette.kTitle,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Palette.kMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: () {
                    // TODO: navegar a edición de perfil
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Acción: Editar perfil')),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, color: Palette.kPrimary),
                )
              ],
            ),
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
                    value: favoritos,
                    icon: Icons.favorite,
                  ),
                ),
                _vDivider(),
                Expanded(
                  child: _StatTile(
                    label: 'Cuponeras',
                    value: cuponeras,
                    icon: Icons.qr_code_2,
                  ),
                ),
                _vDivider(),
                Expanded(
                  child: _StatTile(
                    label: 'Escaneos',
                    value: escaneos,
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
                if (ciudades.isEmpty)
                  const Text('Aún no configuras ciudades', style: TextStyle(color: Palette.kMuted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: -6,
                    children: [
                      for (final c in ciudades) _Chip(c),
                    ],
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
                _sectionTitle(Icons.category_outlined, 'Categorías favoritas'),
                const SizedBox(height: 10),
                if (categoriasFav.isEmpty)
                  const Text('Aún no seleccionas categorías', style: TextStyle(color: Palette.kMuted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: -6,
                    children: [
                      for (final t in categoriasFav) _Chip(t),
                    ],
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
                  subtitle: 'Nombre, avatar y correo',
                  onTap: () {},
                ),
                _divider(),
                _SettingTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notificaciones',
                  subtitle: 'Promociones y alertas',
                  onTap: () {},
                ),
                _divider(),
                _SettingTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacidad',
                  subtitle: 'Permisos y datos',
                  onTap: () {},
                ),
                _divider(),
                _SettingTile(
                  icon: Icons.logout,
                  title: 'Cerrar sesión',
                  subtitle: 'Salir de tu cuenta',
                  danger: true,
                  onTap: () {
                    // TODO: logout real
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sesión cerrada (demo)')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardBox() {
    return BoxDecoration(
      color: Palette.kSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Palette.kBorder),
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
        Icon(icon, color: Palette.kMuted, size: 18),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700)),
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
        Icon(icon, color: Palette.kPrimary, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: const TextStyle(
                  color: Palette.kTitle,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                )),
            Text(label, style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.kField,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Palette.kBorder),
      ),
      child: Text(text, style: const TextStyle(color: Palette.kMuted)),
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
    final color = danger ? Colors.redAccent : Palette.kTitle;
    final sub = danger ? Colors.redAccent.shade200 : Palette.kMuted;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Palette.kField,
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(color: sub)) : null,
      trailing: const Icon(Icons.chevron_right, color: Palette.kMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}
