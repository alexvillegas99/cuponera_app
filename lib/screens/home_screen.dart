import 'package:enjoy/screens/cupones_screen.dart';
import 'package:enjoy/screens/estadisticas_screen.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:flutter/material.dart';
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
      final data = await historicoService.obtenerHistorialCompleto();
      setState(() {
        cupones = data.cast<Map<String, dynamic>>();
        cargando = false;
      });
    } catch (e) {
      setState(() {
        cargando = false;
      });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Error'),
          content: Text('No se pudo obtener el historial de cupones.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {


    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Tu Cuponera',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF398AE5),
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF398AE5)),
              tooltip: 'Actualizar',
              onPressed: () {
                setState(() {
                  cargando = true;
                }); 
                cargarCupones();
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF398AE5)),
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('¿Cerrar sesión?'),
                    content: Text(
                      '¿Estás seguro de que deseas salir de la aplicación?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                );

                if (confirmar == true) {
                  await authService.logout();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF398AE5),
            labelColor: Color(0xFF398AE5),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.confirmation_num), text: 'Cupones'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Estadísticas'),
            ],
          ),
        ),
        body: cargando
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  CuponesScreen(cupones: cupones),
                  EstadisticasScreen(),
                ],
              ),
      ),
    );
  }
}
