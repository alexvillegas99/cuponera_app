import 'package:enjoy/config/navigation/empresa_nav_config.dart';
import 'package:enjoy/screens/chat/chat_entry_screen.dart';
import 'package:enjoy/screens/usuarios/cupones_screen.dart';
import 'package:enjoy/screens/usuarios/promos_flash/mis_promos_flash_screen.dart';
import 'package:enjoy/screens/usuarios/reportes/reportes_landing_screen.dart';
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
import 'package:enjoy/services/session_flows.dart';
import 'package:enjoy/widgets/account_switcher_section.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  final _permissions = PermissionsService();
  final _historicoSvc = HistoricoCuponService();

  /// Id virtual que representa la pantalla de "Panel de gestión" (dashboard).
  static const _panelId = '__panel__';

  // ── Estado general ───────────────────────────────────────────────
  Map<String, dynamic>? _user;
  List<EmpresaNavItem> _items = [];
  String _selectedId = _panelId;
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

    // admin-local / staff entran directo a Cupones (escanear), no al panel.
    final rol = (_user?['rol'] ?? '').toString().toLowerCase();
    if ((rol == 'admin-local' || rol == 'staff') &&
        _items.any((i) => i.id == 'cupones')) {
      _selectedId = 'cupones';
      _loadCupones();
    }

    if (mounted) setState(() => _initLoading = false);
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

  void _goPanel() => setState(() => _selectedId = _panelId);

  // ── Título del módulo activo ─────────────────────────────────────
  String get _currentLabel {
    if (_selectedId == _panelId) return 'Panel de gestión';
    try {
      return _items.firstWhere((i) => i.id == _selectedId).label;
    } catch (_) {
      return 'Enjoy';
    }
  }

  // ── Datos de usuario ─────────────────────────────────────────────
  String get _nombre {
    final n = (_user?['nombre'] ?? _user?['nombres'] ?? '').toString().trim();
    final a = (_user?['apellidos'] ?? '').toString().trim();
    final full = [n, a].where((s) => s.isNotEmpty).join(' ');
    return full.isEmpty ? 'Usuario' : full;
  }

  String get _rol => (_user?['rol'] ?? '').toString().toLowerCase();

  String _rolLabel(String rol) {
    switch (rol) {
      case 'admin-local':
        return 'Admin Local';
      case 'admin':
        return 'Administrador';
      case 'staff':
        return 'Staff';
      default:
        return rol.isEmpty ? 'Usuario' : _capitalize(rol);
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Logout ───────────────────────────────────────────────────────
  Future<void> _confirmLogout() async {
    HapticFeedback.selectionClick();
    // Pregunta si mantener la sesión guardada (biometría) y enruta.
    await SessionFlows.confirmLogout(context);
  }

  // ── Body según módulo activo ─────────────────────────────────────
  Widget _buildBody() {
    switch (_selectedId) {
      case _panelId:
        return _PanelDashboard(
          nombre: _nombre,
          rolLabel: _rolLabel(_rol),
          items: _items,
          onSelect: _onSelect,
          onLogout: _confirmLogout,
        );
      case 'cupones':
        if (_cuponesLoading) {
          return Center(
              child: CircularProgressIndicator(color: context.ec.orange));
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
      case 'chats':
        return const ChatEntryScreen();
      case 'promos_flash':
        return const MisPromosFlashScreen(embedded: true);
      case 'reportes':
        return const ReportesLandingScreen(embedded: true);
      default:
        return const Center(child: Text('Módulo no disponible'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    if (_initLoading) {
      return EnjoyScaffold(
        body: Center(child: CircularProgressIndicator(color: ec.orange)),
      );
    }

    final isPanel = _selectedId == _panelId;

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: isPanel
          ? null
          : EnjoyAppBar(
              title: _currentLabel,
              showBack: true,
              onBack: _goPanel,
              actions: [
                if (_selectedId == 'cupones')
                  GlassIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => _loadCupones(forceRefresh: true),
                  ),
              ],
            ),
      body: _buildBody(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PANEL DASHBOARD — mockup #1
// ══════════════════════════════════════════════════════════════════

class _PanelDashboard extends StatelessWidget {
  const _PanelDashboard({
    required this.nombre,
    required this.rolLabel,
    required this.items,
    required this.onSelect,
    required this.onLogout,
  });

  final String nombre;
  final String rolLabel;
  final List<EmpresaNavItem> items;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera: avatar + rol + logout ──
          RiseIn(
            child: Row(
              children: [
                EnjoyAvatar(nombre, size: 44, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EnjoyTheme.heading(size: 15, color: ec.text),
                      ),
                      const SizedBox(height: 4),
                      Pill(rolLabel, variant: PillVariant.blue, dense: true),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GlassIconButton(
                  icon: Icons.logout_rounded,
                  color: ec.red,
                  onTap: onLogout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Card de bienvenida con KPIs ──
          RiseIn(
            delayMs: 60,
            child: GlassCard(
              accent: true,
              padding: const EdgeInsets.all(18),
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bienvenido a',
                      style: EnjoyTheme.body(size: 12, color: ec.textMute)),
                  const SizedBox(height: 2),
                  Text(
                    'ENJOY · Panel de gestión',
                    style: EnjoyTheme.heading(size: 22, color: ec.orangeSoft),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── Cambiar de cuenta (solo si hay cuenta de cliente del mismo correo) ──
          const AccountSwitcherSection(showAdd: false),

          // ── Grid de módulos ──
          SectionTitle('Módulos'),
          const SizedBox(height: 12),
          RiseIn(
            delayMs: 120,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: 0.95,
              children: [
                for (final item in items)
                  _ModuleCard(
                    item: item,
                    accent: item.id == 'cupones',
                    onTap: () => onSelect(item.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de módulo ─────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.item,
    required this.accent,
    required this.onTap,
  });

  final EmpresaNavItem item;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconBox(item.icon, accent: accent),
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EnjoyTheme.heading(size: 12, color: ec.text),
          ),
        ],
      ),
    );
  }
}
