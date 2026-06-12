import 'package:enjoy/services/reportes_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils/reportes_utils.dart';
import 'widgets/reportes_widgets.dart';

class CanjesReporteScreen extends StatefulWidget {
  const CanjesReporteScreen({super.key});

  @override
  State<CanjesReporteScreen> createState() => _CanjesReporteScreenState();
}

class _CanjesReporteScreenState extends State<CanjesReporteScreen> {
  final _svc = ReportesService();

  DateTime _desde = DateTime.now().subtract(const Duration(days: 90));
  DateTime _hasta = DateTime.now();
  bool _loading = true;

  Map<String, dynamic>? _canjes;
  Map<String, dynamic>? _ingresos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final r = RangoFechas(
        desde: DateFormat('yyyy-MM-dd').format(_desde),
        hasta: DateFormat('yyyy-MM-dd').format(_hasta),
      );
      final results = await Future.wait([
        _svc.canjes(r, granularidad: 'dia'),
        _svc.ingresos(r),
      ]);
      if (!mounted) return;
      setState(() {
        _canjes = results[0];
        _ingresos = results[1];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compartir() async {
    final serie = (_canjes?['serie'] as List?) ?? [];
    final rows = serie
        .map((s) => {
              'fecha': s['fecha'],
              'canjes': s['canjes'],
            })
        .toList();
    await shareCsv(
      'canjes-por-fecha',
      List<Map<String, dynamic>>.from(rows),
      const [
        (key: 'fecha', label: 'Fecha'),
        (key: 'canjes', label: 'Canjes'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Canjes & Ingresos'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ReporteHeader(
            icon: Icons.trending_up_rounded,
            title: 'Canjes & Ingresos',
            subtitle: 'Tendencia y rendimiento del período',
            onCompartir: _canjes == null ? null : _compartir,
          ),
          const SizedBox(height: 14),
          FiltrosFecha(
            desde: _desde,
            hasta: _hasta,
            onDesde: (d) => setState(() => _desde = d),
            onHasta: (d) => setState(() => _hasta = d),
            onActualizar: _cargar,
            loading: _loading,
          ),
          const SizedBox(height: 14),
          if (_loading && _canjes == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: CircularProgressIndicator(color: ec.orange),
              ),
            )
          else if (_canjes != null) ...[
            // KPIs
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                StatKpi(
                  label: 'Canjes',
                  value: fmtN(_canjes!['totalCanjes']),
                ),
                StatKpi(
                  label: 'Ingreso',
                  value: fmtMoney(
                      (_ingresos?['total'] as num?)?.toDouble() ?? 0),
                  accent: true,
                ),
                StatKpi(
                  label: 'Ventas',
                  value: fmtN(_ingresos?['ventas']),
                ),
                StatKpi(
                  label: 'Ticket prom.',
                  value: fmtMoney(
                      (_ingresos?['ticketPromedio'] as num?)?.toDouble() ?? 0),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Gráfico tendencia
            GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tendencia de canjes',
                      style: EnjoyTheme.heading(size: 15, color: ec.text)),
                  Text('Cantidad de cupones canjeados por día',
                      style: EnjoyTheme.body(size: 12, color: ec.textMute)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: _buildLineChart(ec),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Top locales
            Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: ec.orange, size: 18),
                const SizedBox(width: 6),
                Text('Top locales',
                    style: EnjoyTheme.heading(size: 15, color: ec.text)),
              ],
            ),
            const SizedBox(height: 8),
            SimpleTable(
              headers: const ['Local', 'Canjes'],
              rows: ((_canjes!['topLocales'] as List?) ?? [])
                  .take(10)
                  .map<List<Widget>>(
                    (l) => [
                      Text(
                        (l['nombre'] ?? '').toString(),
                        style: EnjoyTheme.body(
                            size: 13,
                            color: ec.text,
                            weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        fmtN(l['canjes']),
                        style: EnjoyTheme.heading(size: 14, color: ec.orange),
                      ),
                    ],
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),

            // Métodos de pago
            if ((_ingresos?['porMetodo'] as List?)?.isNotEmpty ?? false) ...[
              Text('Métodos de pago',
                  style: EnjoyTheme.heading(size: 15, color: ec.text)),
              const SizedBox(height: 8),
              SimpleTable(
                headers: const ['Método', 'Ventas', 'Monto'],
                rows: (_ingresos!['porMetodo'] as List)
                    .map<List<Widget>>(
                      (m) => [
                        Text(
                          (m['metodo'] ?? '').toString().toUpperCase(),
                          style: EnjoyTheme.body(
                              size: 13,
                              color: ec.text,
                              weight: FontWeight.w600),
                        ),
                        Text(
                          fmtN(m['ventas']),
                          style: EnjoyTheme.body(size: 13, color: ec.textSoft),
                        ),
                        Text(
                          fmtMoney((m['monto'] as num?)?.toDouble() ?? 0),
                          style: EnjoyTheme.heading(size: 14, color: ec.green),
                        ),
                      ],
                    )
                    .toList(),
              ),
            ],
          ] else
            GlassCard(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Text('No se pudo cargar el reporte',
                    style: EnjoyTheme.body(color: ec.textMute)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLineChart(EnjoyColors ec) {
    final serie =
        ((_canjes?['serie'] as List?) ?? []).cast<Map<String, dynamic>>();
    if (serie.isEmpty) {
      return Center(
        child: Text('Sin canjes en el período',
            style: EnjoyTheme.body(color: ec.textMute)),
      );
    }
    final spots = <FlSpot>[];
    double maxY = 0;
    for (int i = 0; i < serie.length; i++) {
      final y = (serie[i]['canjes'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), y));
      if (y > maxY) maxY = y;
    }
    if (maxY == 0) maxY = 1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (serie.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.15,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY > 5 ? (maxY / 4).ceilToDouble() : 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: ec.stroke,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(color: ec.textMute, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (serie.length / 5).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= serie.length) return const SizedBox.shrink();
                final f = serie[i]['fecha'].toString();
                final corta =
                    f.length >= 10 ? f.substring(5) : f; // MM-DD
                return Text(corta,
                    style:
                        TextStyle(color: ec.textMute, fontSize: 9.5));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: ec.orange,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ec.orange.withValues(alpha: 0.35),
                  ec.orange.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
