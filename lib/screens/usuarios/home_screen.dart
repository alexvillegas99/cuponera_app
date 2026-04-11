import 'package:enjoy/config/navigation/empresa_nav_config.dart';
import 'package:enjoy/screens/usuarios/cupones_screen.dart';
import 'package:enjoy/screens/usuarios/empleados_screen.dart';
import 'package:enjoy/screens/usuarios/establecimientos_screen.dart';
import 'package:enjoy/screens/usuarios/estadisticas_screen.dart';
import 'package:enjoy/screens/usuarios/perfil_local_screen.dart';
import 'package:enjoy/screens/usuarios/cupones_asignados_screen.dart';
import 'package:enjoy/screens/usuarios/nueva_cuponera_admin_screen.dart';
import 'package:enjoy/screens/usuarios/solicitudes_admin_screen.dart';
import 'package:enjoy/screens/usuarios/usuarios_admin_screen.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:enjoy/services/permissions_service.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  final _permissions = PermissionsService();
  final _historicoSvc = HistoricoCuponService();

  // ── Estado general ───────────────────────────────────────────────
  Map<String, dynamic>? _user;
  List<EmpresaNavItem> _items = [];
  String _selectedId = 'cupones';
  bool _initLoading = true;

  // ── Estado de cupones ────────────────────────────────────────────
  List<Map<String, dynamic>> _cupones = [];
  bool _cuponesLoading = false;
  bool _cuponesLoaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _user = await _auth.getUser();
    _items = await _buildItems();

    if (_items.isNotEmpty) {
      _selectedId = _items.first.id;
    }

    if (mounted) setState(() => _initLoading = false);

    // Cargar cupones si es el módulo inicial
    if (_selectedId == 'cupones') _loadCupones();
  }

  Future<List<EmpresaNavItem>> _buildItems() async {
    final rol = await _permissions.getRol();
    final result = <EmpresaNavItem>[];
    for (final item in kEmpresaNavItems) {
      // excludeRoles tiene precedencia absoluta sobre cualquier permiso
      if (item.excludeRoles != null && item.excludeRoles!.contains(rol)) {
        continue;
      }

      // Sin restricción de permiso: siempre visible
      if (item.permission == null) {
        result.add(item);
        continue;
      }

      // Permiso dinámico (array de permisos del usuario)
      final tienePermiso = await _permissions.hasPermission(item.permission!);
      // Fallback por rol: si el rol está en fallbackRoles, también da acceso
      final porRol = item.fallbackRoles?.contains(rol) ?? false;

      if (tienePermiso || porRol) result.add(item);
    }
    return result;
  }

  Future<void> _loadCupones({bool forceRefresh = false}) async {
    if (_cuponesLoaded && !forceRefresh) return;
    final userId = _user?['_id']?.toString();
    if (userId == null) return;

    setState(() => _cuponesLoading = true);
    try {
      final data = await _historicoSvc.obtenerPorUsuario(userId);
      if (mounted) {
        setState(() {
          _cupones = data.cast<Map<String, dynamic>>();
          _cuponesLoading = false;
          _cuponesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cuponesLoading = false);
    }
  }

  void _onSelect(String id) {
    setState(() => _selectedId = id);
    if (id == 'cupones' && !_cuponesLoaded) _loadCupones();
  }

  // ── Título del módulo activo ─────────────────────────────────────
  String get _currentLabel {
    try {
      return _items.firstWhere((i) => i.id == _selectedId).label;
    } catch (_) {
      return 'Enjoy';
    }
  }

  // ── Logout ───────────────────────────────────────────────────────
  Future<void> _confirmLogout() async {
    HapticFeedback.selectionClick();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withOpacity(0.25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(ctx).viewInsets.bottom),
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.red),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '¿Cerrar sesión?',
                    style: TextStyle(
                      color: Palette.kTitle,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Se cerrará tu sesión en esta aplicación.',
                style: TextStyle(color: Palette.kMuted),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Palette.kBorder),
                      foregroundColor: Palette.kMuted,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Cerrar sesión'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      await _auth.logout();
      if (mounted) context.go('/login');
    }
  }

  // ── Body según módulo activo ─────────────────────────────────────
  Widget _buildBody() {
    switch (_selectedId) {
      case 'cupones':
        if (_cuponesLoading) {
          return const Center(
              child: CircularProgressIndicator(color: Palette.kAccent));
        }
        return CuponesScreen(
          cupones: _cupones,
          onScanSuccess: (item) {
            final newId = (item['cupon'] as Map?)?['_id']?.toString();
            final exists = newId != null &&
                _cupones.any(
                    (c) => (c['cupon'] as Map?)?['_id']?.toString() == newId);
            if (!exists) setState(() => _cupones.insert(0, item));
          },
        );
      case 'estadisticas':
        return const EstadisticasScreen();
      case 'empleados':
        return const EmpleadosScreen();
      case 'perfil_local':
        return const PerfilLocalScreen();
      case 'establecimientos':
        return const EstablecimientosScreen();
      case 'usuarios':
        return const UsuariosAdminScreen();
      case 'solicitudes':
        return const SolicitudesAdminScreen();
      case 'nueva_cuponera':
        return const NuevaCuponeraAdminScreen();
      case 'cupones_asignados':
        return const CuponesAsignadosScreen();
      default:
        return const Center(child: Text('Módulo no disponible'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initLoading) {
      return const Scaffold(
        backgroundColor: Palette.kBg,
        body: Center(child: CircularProgressIndicator(color: Palette.kAccent)),
      );
    }

    return Scaffold(
      backgroundColor: Palette.kBg,
      drawer: _EmpresaDrawer(
        user: _user,
        items: _items,
        selectedId: _selectedId,
        onSelect: (id) {
          Navigator.of(context).pop();
          _onSelect(id);
        },
        onLogout: _confirmLogout,
      ),
      appBar: _buildAppBar(context),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Palette.kSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Palette.kSurface,
          border: Border(bottom: BorderSide(color: Palette.kBorder, width: 1)),
        ),
      ),
      leading: Builder(
        builder: (ctx) => GestureDetector(
          onTap: () => Scaffold.of(ctx).openDrawer(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Palette.kField,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Palette.kBorder),
            ),
            child: const Icon(Icons.menu_rounded, color: Palette.kTitle, size: 20),
          ),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          _currentLabel,
          style: const TextStyle(
            color: Palette.kTitle,
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: .2,
          ),
        ),
      ),
      actions: [
        if (_selectedId == 'cupones')
          _ActionBtn(
            icon: Icons.refresh_rounded,
            color: Palette.kAccent,
            tooltip: 'Actualizar cupones',
            onTap: () => _loadCupones(forceRefresh: true),
          ),
        const SizedBox(width: 12),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DRAWER
// ══════════════════════════════════════════════════════════════════════════════

class _EmpresaDrawer extends StatelessWidget {
  final Map<String, dynamic>? user;
  final List<EmpresaNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;

  const _EmpresaDrawer({
    required this.user,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.onLogout,
  });

  String get _nombre {
    final n = (user?['nombre'] ?? user?['nombres'] ?? '').toString().trim();
    final a = (user?['apellidos'] ?? '').toString().trim();
    final full = [n, a].where((s) => s.isNotEmpty).join(' ');
    return full.isEmpty ? 'Usuario' : full;
  }

  String get _correo =>
      (user?['correo'] ?? user?['email'] ?? '').toString();

  String get _rol => (user?['rol'] ?? '').toString().toLowerCase();

  String _rolLabel(String rol) {
    switch (rol) {
      case 'admin-local': return 'Admin Local';
      case 'admin': return 'Administrador';
      case 'staff': return 'Staff';
      default: return rol.isEmpty ? 'Usuario' : _capitalize(rol);
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final initial = _nombre.isNotEmpty ? _nombre[0].toUpperCase() : 'U';

    return Drawer(
      width: 285,
      backgroundColor: Palette.kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF152A47), Color(0xFF1E3A6E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 20,
              20,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Palette.kAccent, Palette.kAccentLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.kAccent.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_activity_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENJOY',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.2,
                            height: 1,
                          ),
                        ),
                        Text(
                          'Panel de gestión',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Usuario info
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Palette.kAccent, Palette.kAccentLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.kAccent.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Rol badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Palette.kAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Palette.kAccent.withOpacity(0.35)),
                            ),
                            child: Text(
                              _rolLabel(_rol),
                              style: const TextStyle(
                                color: Palette.kAccentLight,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_correo.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _correo,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Sección: MÓDULOS ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                Text(
                  'MÓDULOS',
                  style: TextStyle(
                    color: Palette.kMuted.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Items de navegación ─────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final isSelected = item.id == selectedId;
                return _NavItem(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onSelect(item.id),
                );
              },
            ),
          ),

          // ── Footer: logout ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Palette.kBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + safeBottom * 0),
                child: _LogoutBtn(onTap: onLogout),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item de navegación ───────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final EmpresaNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Palette.kAccent, Palette.kAccentLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Palette.kAccent.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 20,
              color: isSelected ? Colors.white : Palette.kMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Palette.kTitle,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Botón de logout ──────────────────────────────────────────────────────────

class _LogoutBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.logout_rounded, size: 20, color: Colors.red.shade400),
            const SizedBox(width: 12),
            Text(
              'Cerrar sesión',
              style: TextStyle(
                color: Colors.red.shade500,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botón de app bar ─────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
