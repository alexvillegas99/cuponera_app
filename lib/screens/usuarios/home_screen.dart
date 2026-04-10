// lib/screens/home/home_screen.dart
import 'package:enjoy/screens/usuarios/cupones_screen.dart';
import 'package:enjoy/screens/usuarios/estadisticas_screen.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
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
  final authService = AuthService();
  final historicoService = HistoricoCuponService();

  List<Map<String, dynamic>> cupones = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarCupones();
  }

  Future<void> cargarCupones() async {
    try {
      final usuario = await authService.getUser();
      final String? userId = usuario?['_id']?.toString();
      final String? rol = usuario?['rol']?.toString();
      final String? usuarioCreacion = usuario?['usuarioCreacion']?.toString();
      debugPrint('[HOME] _id=$userId | rol=$rol | usuarioCreacion=$usuarioCreacion');

      if (userId == null) {
        setState(() => cargando = false);
        _showError('No pudimos identificar al usuario.');
        return;
      }

      final data = await historicoService.obtenerPorUsuario(userId);
      debugPrint('[HOME] cupones encontrados: ${data.length}');
      if (!mounted) return;

      setState(() {
        cupones = data.cast<Map<String, dynamic>>();
        cargando = false;
      });
    } catch (e) {
      debugPrint('[HOME] error: $e');
      if (!mounted) return;
      setState(() => cargando = false);
      _showError('No se pudo obtener el historial de cupones.\n$e');
    }
  }

Future<bool?> _showConfirmBottomSheet(
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
            // handle
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),

            // título + icono
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Palette.kAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Palette.kAccent),
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

            // mensaje
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                style: const TextStyle(color: Palette.kMuted),
              ),
            ),
            const SizedBox(height: 16),

            // acciones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Palette.kBorder),
                      foregroundColor: Palette.kMuted,
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
                      backgroundColor: Palette.kAccent,
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


Future<void> _confirmLogout() async {
  final ok = await _showConfirmBottomSheet(
    context,
    title: '¿Cerrar sesión?',
    message: 'Se cerrará tu sesión en esta aplicación.',
    confirmLabel: 'Cerrar sesión',
    cancelLabel: 'Cancelar',
    icon: Icons.logout,
  );

  if (ok == true) {
    await authService.logout();
    if (mounted) context.go('/login');
  }
}

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        surfaceTintColor: Palette.kSurface,
        title: const Text(
          'Error',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Palette.kBg,
        appBar: AppBar(
          backgroundColor: Palette.kSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: Palette.kSurface,
              border: Border(
                bottom: BorderSide(color: Palette.kBorder, width: 1),
              ),
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Palette.kAccent, Palette.kAccentLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Palette.kAccent.withOpacity(0.35),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ENJOY',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Palette.kTitle,
                        fontSize: 18,
                        letterSpacing: .8,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Gestión de cupones',
                      style: TextStyle(
                        color: Palette.kMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            _AppBarBtn(
              icon: Icons.refresh_rounded,
              color: Palette.kAccent,
              tooltip: 'Actualizar',
              onTap: () async {
                setState(() => cargando = true);
                await cargarCupones();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Actualizado')),
                );
              },
            ),
            const SizedBox(width: 8),
            _AppBarBtn(
              icon: Icons.logout_rounded,
              color: Palette.kMuted,
              tooltip: 'Cerrar sesión',
              onTap: _confirmLogout,
            ),
            const SizedBox(width: 12),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Palette.kField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.kBorder),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Palette.kAccent, Palette.kAccentLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Palette.kAccent.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Palette.kMuted,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.confirmation_num_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Cupones'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Estadísticas'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: cargando
            ? const Center(
                child: CircularProgressIndicator(color: Palette.kAccent),
              )
            : TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  CuponesScreen(
                    cupones: cupones,
                    onScanSuccess: (item) {
                      final newId = (item['cupon'] as Map?)?['_id']?.toString();
                      final exists = newId != null &&
                          cupones.any((c) =>
                              (c['cupon'] as Map?)?['_id']?.toString() == newId);
                      if (!exists) setState(() => cupones.insert(0, item));
                    },
                  ),
                  const EstadisticasScreen(),
                ],
              ),
      ),
    );
  }
}

// ── Botón de app bar ──────────────────────────────────────────────

class _AppBarBtn extends StatelessWidget {
  const _AppBarBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

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
