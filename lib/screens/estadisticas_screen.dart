import 'dart:math';
import 'package:cuponera_app/services/color_generator_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EstadisticasScreen extends StatefulWidget {
  final List<Map<String, dynamic>> datosPorDia;

  const EstadisticasScreen({super.key, required this.datosPorDia});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  DateTime fechaInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime fechaFin = DateTime.now();
  late List<Color> colores;

  @override
  void initState() {
    super.initState();
    colores = ColorGeneratorService().generateColors(widget.datosPorDia.length);
  }

 int get cuponesHoy {
  final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return (widget.datosPorDia
          .firstWhere(
            (d) => d['fecha'] == hoy,
            orElse: () => <String, Object>{'cupones': 0},
          )['cupones'] as num)
      .toInt();
}


  int get cuponesTotales {
    return widget.datosPorDia.fold<int>(
      0,
      (sum, item) => sum + ((item['cupones'] ?? 0) as num).toInt(),
    );
  }

  Future<void> seleccionarFechaRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: fechaInicio, end: fechaFin),
    );
    if (picked != null) {
      setState(() {
        fechaInicio = picked.start;
        fechaFin = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtro de fecha
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: seleccionarFechaRango,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    '${DateFormat('dd/MM').format(fechaInicio)} - ${DateFormat('dd/MM').format(fechaFin)}',
                  ),
                ),
                const Spacer(),
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
              ],
            ),
          ),

          // Métricas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(title: 'Escaneos hoy', value: '$cuponesHoy'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(title: 'Total escaneados', value: '$cuponesTotales'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Gráfico de barras
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: false),
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(widget.datosPorDia) + 5,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, _) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < widget.datosPorDia.length) {
                            final fecha = DateFormat('dd/MM')
                                .format(DateTime.parse(widget.datosPorDia[index]['fecha']));
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                fecha,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: widget.datosPorDia.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    final cantidad = (data['cupones'] ?? 0).toDouble();

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: cantidad,
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: [
                              colores[index].withOpacity(0.8),
                              colores[index],
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ],
                      showingTooltipIndicators: [0],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Gráfico circular
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Participación por día',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: _generarSeccionesPastel(widget.datosPorDia),
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generarSeccionesPastel(
    List<Map<String, dynamic>> datos,
  ) {
    final total = datos.fold<num>(
      0,
      (sum, item) => sum + (item['cupones'] ?? 0),
    );
    if (total == 0) return [];

    return datos.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final porcentaje = ((item['cupones'] ?? 0) / total) * 100;
      final fecha = DateFormat('dd/MM').format(DateTime.parse(item['fecha']));

      return PieChartSectionData(
        value: porcentaje,
        title: '${porcentaje.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: colores[index % colores.length],
        radius: 60,
        badgeWidget: Text(fecha, style: const TextStyle(fontSize: 10)),
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

double _getMaxY(List<Map<String, dynamic>> datos) {
  if (datos.isEmpty) return 10;
  return datos
      .map((e) => (e['cupones'] ?? 0).toDouble())
      .reduce((a, b) => a > b ? a : b);
}

}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF64B5F6), Color(0xFF398AE5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
