import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/color_generator_service.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  DateTime fechaInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime fechaFin = DateTime.now();

  final authService = AuthService();
  final historicoService = HistoricoCuponService();

  // Datos crudos (incluyen días con 0)
  List<Map<String, dynamic>> datosPorDia =
      []; // [{fecha:'yyyy-MM-dd', cupones:int}]
  List<Color> colores = [];
  bool cargando = true;
  String? mensajeError;

  // --- helpers para el chart ---
  // (mantenemos por si vuelves a querer scroll en el futuro)
  int _labelStepForCount(int n, {int targetLabels = 7}) {
    return (n / targetLabels).ceil().clamp(1, 999);
  }

  List<Map<String, dynamic>> get _datosParaGraficos {
    // 1) quita días con 0  2) toma máximo 10  3) mantiene orden desde fechaInicio
    final filtered = datosPorDia
        .where((e) => ((e['cupones'] ?? 0) as num) > 0)
        .toList();
    return filtered.take(10).toList();
  }

  List<Color> get _coloresGrafico {
    if (_datosParaGraficos.isEmpty) return [];
    // genera/recorta tantos colores como puntos se grafiquen (<=10)
    final n = _datosParaGraficos.length;
    final base = colores.isEmpty
        ? _fallbackColors(n)
        : (colores.length >= n
              ? colores
              : [...colores, ..._fallbackColors(n - colores.length)]);
    return base.take(n).toList();
  }

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    if (!mounted) return;
    setState(() {
      cargando = true;
      mensajeError = null;
    });

    try {
      final usuario = await authService.getUser();
      if (!mounted) return;

      final raw = await historicoService.buscarDashboardPorUsuarioYFechas(
        id: usuario?['_id'],
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
      if (!mounted) return;

      // Agregar por día (en local)
      final Map<String, int> agrupado = {};
      for (final item in raw) {
        final iso = item['fechaEscaneo']?.toString();
        if (iso == null || iso.isEmpty) continue;
        DateTime dt;
        try {
          dt = DateTime.parse(iso).toLocal();
        } catch (_) {
          continue;
        }
        final key = DateFormat('yyyy-MM-dd').format(dt);
        agrupado[key] = (agrupado[key] ?? 0) + 1;
      }

      // Cobertura completa del rango (incluye 0, para totales y “hoy”)
      final List<Map<String, dynamic>> datos = [];
      for (
        DateTime d = _stripTime(fechaInicio);
        !d.isAfter(_stripTime(fechaFin));
        d = d.add(const Duration(days: 1))
      ) {
        final k = DateFormat('yyyy-MM-dd').format(d);
        datos.add({'fecha': k, 'cupones': agrupado[k] ?? 0});
      }

      // Colores base suficientes
      final cg = ColorGeneratorService();
      var cols = <Color>[];
      try {
        cols = cg.generateColors(datos.length);
      } catch (_) {
        cols = _fallbackColors(datos.length);
      }
      if (cols.length < datos.length) {
        cols.addAll(_fallbackColors(datos.length - cols.length));
      }

      if (!mounted) return;
      setState(() {
        datosPorDia = datos;
        colores = cols;
        cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        mensajeError = 'Ocurrió un problema al cargar los datos.';
        cargando = false;
      });
    }
  }

  Future<void> _refresh() => cargarDatos();

  Future<void> seleccionarFechaRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: fechaInicio, end: fechaFin),
    );
    if (picked != null) {
      setState(() {
        fechaInicio = _stripTime(picked.start);
        fechaFin = _stripTime(picked.end);
      });
      await cargarDatos();
    }
  }

  void setQuickRange(Duration d) {
    setState(() {
      fechaFin = _stripTime(DateTime.now());
      fechaInicio = _stripTime(DateTime.now().subtract(d));
    });
    cargarDatos();
  }

  int get cuponesHoy {
    final hoy = DateFormat('yyyy-MM-dd').format(_stripTime(DateTime.now()));
    final found = datosPorDia.firstWhere(
      (d) => d['fecha'] == hoy,
      orElse: () => {'cupones': 0},
    );
    return (found['cupones'] as num).toInt();
  }

  int get cuponesTotales {
    return datosPorDia.fold<int>(
      0,
      (sum, item) => sum + ((item['cupones'] ?? 0) as num).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Header SIEMPRE visible
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: seleccionarFechaRango,
            icon: const Icon(Icons.date_range),
            label: Text(
              '${DateFormat('dd/MM').format(fechaInicio)} - ${DateFormat('dd/MM').format(fechaFin)}',
            ),
          ),
          const SizedBox(width: 8),
          _QuickChip(
            text: 'Hoy',
            onTap: () => setQuickRange(const Duration(days: 0)),
          ),
          const SizedBox(width: 6),
          _QuickChip(
            text: '7d',
            onTap: () => setQuickRange(const Duration(days: 7)),
          ),
          const SizedBox(width: 6),
          _QuickChip(
            text: '30d',
            onTap: () => setQuickRange(const Duration(days: 30)),
          ),
          const Spacer(),
          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
        ],
      ),
    );

    if (cargando) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    final datosBarras = _datosParaGraficos; // <= filtrado (sin ceros, máx 10)
    final coloresBarras = _coloresGrafico;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,

            // Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Escaneos hoy',
                      value: '$cuponesHoy',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Total escaneados',
                      value: '$cuponesTotales',
                    ),
                  ),
                ],
              ),
            ),

            if (mensajeError != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _InfoBanner(
                  text: mensajeError!,
                  icon: Icons.info_outline,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // BARRAS (sin días 0, máx 10; sólo número arriba)
            _SectionTitle(text: 'Escaneos por día'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 260,
                child: datosBarras.isNotEmpty
                    ? BarChart(
                        BarChartData(
                          gridData: FlGridData(show: false),
                          alignment: BarChartAlignment.spaceAround,
                          groupsSpace: 10,
                          maxY: (_getMaxY(datosBarras) * 1.2).clamp(
                            5,
                            double.infinity,
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            // arriba: SOLO el número (conteo de cada barra)
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, _) {
                                  final i = value.toInt();
                                  if (i < 0 || i >= datosBarras.length)
                                    return const SizedBox.shrink();
                                  final n = (datosBarras[i]['cupones'] ?? 0)
                                      .toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      n,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // abajo: NO mostrar fechas para que no se vea cargado
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 26,
                                getTitlesWidget: (value, _) {
                                  final i = value.toInt();
                                  if (i < 0 || i >= datosBarras.length)
                                    return const SizedBox.shrink();
                                  final fecha = DateFormat('dd/MM').format(
                                    DateTime.parse(datosBarras[i]['fecha']),
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      fecha,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                         
                          barGroups: datosBarras.asMap().entries.map((entry) {
                            final i = entry.key;
                            final d = entry.value;
                            final y = (d['cupones'] ?? 0).toDouble();
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: y,
                                  width: 18,
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(
                                    colors: [
                                      coloresBarras[i % coloresBarras.length]
                                          .withOpacity(0.85),
                                      coloresBarras[i % coloresBarras.length],
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
                      )
                    : _EmptyChart(
                        height: 260,
                        hint: 'No hay escaneos (se omiten días con 0).',
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // PIE (sin días 0, máx 10)
            _SectionTitle(text: 'Participación por día'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 220,
                child: datosBarras.isNotEmpty
                    ? PieChart(
                        PieChartData(
                          sections: _generarSeccionesPastel(
                            datosBarras,
                            coloresBarras,
                          ),
                          centerSpaceRadius: 34,
                          sectionsSpace: 2,
                          pieTouchData: PieTouchData(enabled: true),
                        ),
                      )
                    : _EmptyChart(
                        height: 220,
                        hint: 'Aún no hay participación para mostrar.',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========= Helpers =========

  bool _hasAnyData() => datosPorDia.any((e) => (e['cupones'] ?? 0) > 0);

  List<Color> _fallbackColors(int n) {
    final List<Color> out = [];
    for (var i = 0; i < n; i++) {
      final h = (i * 47) % 360;
      out.add(HSLColor.fromAHSL(1, h.toDouble(), 0.65, 0.55).toColor());
    }
    return out;
  }

  List<PieChartSectionData> _generarSeccionesPastel(
    List<Map<String, dynamic>> datos,
    List<Color> cols,
  ) {
    final total = datos.fold<num>(
      0,
      (sum, item) => sum + (item['cupones'] ?? 0),
    );
    if (total == 0) return [];

    return datos.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final count = (item['cupones'] ?? 0) as num;
      final porcentaje = (count / total) * 100;
      final fecha = DateFormat('dd/MM').format(DateTime.parse(item['fecha']));

      return PieChartSectionData(
        value: porcentaje.toDouble(),
        title: '${porcentaje.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: cols[index % cols.length],
        radius: 62,
        badgeWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(fecha, style: const TextStyle(fontSize: 10)),
        ),
        badgePositionPercentageOffset: 1.25,
      );
    }).toList();
  }

  double _getMaxY(List<Map<String, dynamic>> datos) {
    if (datos.isEmpty) return 10;
    final m = datos
        .map((e) => (e['cupones'] ?? 0).toDouble())
        .fold<double>(0, (p, c) => c > p ? c : p);
    return m == 0 ? 5 : m;
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);
}

// ======= UI sub-widgets =======

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF0D47A1),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFE3F2FD),
          border: Border.all(color: const Color(0xFF90CAF9)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1565C0),
          ),
        ),
      ),
    );
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFA000)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.height, required this.hint});
  final double height;
  final String hint;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(hint, style: TextStyle(color: Colors.grey.shade600)),
    );
  }
}
