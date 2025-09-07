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
      final usuario = await authService.getUser(); // Map<String, dynamic>?
      final String? userId = usuario?['_id']?.toString(); // ✅ null-safe

      if (userId == null) {
        setState(() => cargando = false);
        _showError('No pudimos identificar al usuario.');
        return;
      }

      final data = await historicoService.obtenerPorUsuario(userId);
      if (!mounted) return;

      setState(() {
        cupones = data.cast<Map<String, dynamic>>();
        cargando = false;
      });
    } catch (e) {
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
                      side: BorderSide(color: Palette.kPrimary.withOpacity(0.25)),
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
          backgroundColor: Palette.kBg,
          elevation: 0,
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 8),
              Container(
                height: 34,
                width: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Palette.kPrimary, Palette.kAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.local_activity_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'ENJOY',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Palette.kTitle,
                  fontSize: 20,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh_rounded, color: Palette.kPrimary),
              onPressed: () async {
                setState(() => cargando = true);
                await cargarCupones();
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Actualizado')));
              },
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout_rounded, color: Palette.kPrimary),
              onPressed: _confirmLogout,
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            indicatorColor: Palette.kPrimary,
            labelColor: Palette.kPrimary,
            unselectedLabelColor: Palette.kMuted,
            tabs: [
              Tab(icon: Icon(Icons.confirmation_num_rounded), text: 'Cupones'),
              Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Estadísticas'),
            ],
          ),
        ),
        body: cargando
            ? const Center(
                child: CircularProgressIndicator(color: Palette.kPrimary),
              )
            : TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  CuponesScreen(
                    cupones: cupones,
                    onAfterScan: () async {
                      // 👈 NUEVO
                      setState(() => cargando = true);
                      await cargarCupones(); // 👈 recarga desde backend
                    },
                  ),
                  const EstadisticasScreen(),
                ],
              ),
      ),
    );
  }
}
