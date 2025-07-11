import 'package:cuponera_app/screens/cupones_screen.dart';
import 'package:cuponera_app/screens/estadisticas_screen.dart';
import 'package:cuponera_app/services/color_generator_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulación de datos (luego los puedes obtener del backend o estado global)
    final cupones = [
      {
        'numero': 1,

        'fechaInicio': '2025-07-01',
        'fechaFin': '2025-07-31',
        'usuario': 'Jonathan Parra',
        'fechaEscaneo': '2025-07-01 14:30',
      },
      {
        'numero': 2,
        'fechaInicio': '2025-07-02',
        'fechaFin': '2025-07-15',
        'usuario': 'Jonathan Parra',
        'fechaEscaneo': '2025-07-02 10:15',
      },
      {
        'numero': 3,
        'fechaInicio': '2025-07-01',
        'fechaFin': '2025-07-01',
        'usuario': 'Jonathan Parra',
        'fechaEscaneo': '2025-07-01 09:00',
      },
    ];

    final estadisticas = [
      {'fecha': '2025-06-25', 'cupones': 5},
      {'fecha': '2025-06-26', 'cupones': 8},
      {'fecha': '2025-06-27', 'cupones': 4},
      {'fecha': '2025-06-28', 'cupones': 10},
      {'fecha': '2025-06-29', 'cupones': 7},
      {'fecha': '2025-06-30', 'cupones': 12},
      {'fecha': '2025-07-01', 'cupones': 6},
      {'fecha': '2025-06-25', 'cupones': 5},
      {'fecha': '2025-06-26', 'cupones': 8},
      {'fecha': '2025-06-27', 'cupones': 4},
    ];

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
        body: TabBarView(
          children: [
            CuponesScreen(cupones: cupones),
            EstadisticasScreen(datosPorDia: estadisticas),
          ],
        ),
      ),
    );
  }
}
