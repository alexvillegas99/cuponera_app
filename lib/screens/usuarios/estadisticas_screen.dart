import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  DateTime _desde = DateTime.now().subtract(const Duration(days: 6));
  DateTime _hasta = DateTime.now();

  final _auth = AuthService();
  final _svc = HistoricoCuponService();

  List<Map<String, dynamic>> _raw = [];
  List<_DayData> _dias = [];
  List<_PersonData> _scanners = [];
  bool _loading = true;
  String? _error;

  // ── Métricas ──
  int get _total => _raw.length;
  int get _hoy {
    final k = _fmt(_stripTime(DateTime.now()));
    return _dias.firstWhere((d) => d.fecha == k, orElse: () => _DayData(k, 0)).count;
  }
  double get _promedio {
    final activos = _dias.where((d) => d.count > 0).length;
    return activos == 0 ? 0 : _total / activos;
  }
  _DayData? get _peak => _dias.isEmpty
      ? null
      : _dias.reduce((a, b) => a.count >= b.count ? a : b);
  String? get _ultimoEscaneo {
    if (_raw.isEmpty) return null;
    final sorted = [..._raw]..sort((a, b) {
        final fa = DateTime.tryParse(a['fechaEscaneo'] ?? '') ?? DateTime(2000);
        final fb = DateTime.tryParse(b['fechaEscaneo'] ?? '') ?? DateTime(2000);
        return fb.compareTo(fa);
      });
    final dt = DateTime.tryParse(sorted.first['fechaEscaneo'] ?? '')?.toLocal();
    return dt == null ? null : DateFormat('dd MMM yyyy · hh:mm a', 'es').format(dt);
  }

  List<_DayData> get _chartDays =>
      _dias.where((d) => d.count > 0).take(14).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = await _auth.getUser();
      final raw = await _svc.buscarDashboardPorUsuarioYFechas(
        id: user?['_id'],
        fechaInicio: _desde,
        fechaFin: _hasta,
      );
      if (!mounted) return;

      // Agrupar por día
      final Map<String, int> porDia = {};
      final Map<String, int> porScanner = {};

      for (final item in raw) {
        final iso = item['fechaEscaneo']?.toString();
        if (iso != null) {
          final dt = DateTime.tryParse(iso)?.toLocal();
          if (dt != null) {
            final k = _fmt(dt);
            porDia[k] = (porDia[k] ?? 0) + 1;
          }
        }
        final ep = item['escaneadoPor'];
        final nombre = (ep is Map) ? (ep['nombre']?.toString() ?? 'Desconocido') : 'Desconocido';
        porScanner[nombre] = (porScanner[nombre] ?? 0) + 1;
      }

      // Rango completo
      final dias = <_DayData>[];
      for (DateTime d = _stripTime(_desde); !d.isAfter(_stripTime(_hasta)); d = d.add(const Duration(days: 1))) {
        final k = _fmt(d);
        dias.add(_DayData(k, porDia[k] ?? 0));
      }

      final scanners = porScanner.entries
          .map((e) => _PersonData(e.key, e.value))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      setState(() {
        _raw = raw;
        _dias = dias;
        _scanners = scanners;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'No se pudieron cargar los datos.'; _loading = false; });
    }
  }

  Future<void> _pickRange() async {
    final ec = context.ec;
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: ec.orange,
                secondary: ec.orangeSoft,
              ),
        ),
        child: child!,
      ),
    );
    if (r != null) {
      setState(() { _desde = _stripTime(r.start); _hasta = _stripTime(r.end); });
      _load();
    }
  }

  void _quick(int days) {
    setState(() {
      _hasta = _stripTime(DateTime.now());
      _desde = days == 0 ? _hasta : _stripTime(DateTime.now().subtract(Duration(days: days - 1)));
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return RefreshIndicator(
      onRefresh: _load,
      color: ec.orange,
      backgroundColor: ec.surfaceTop,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(child: _buildHeader()),

          // ── Contenido ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_loading)
                  SizedBox(
                      height: 300,
                      child: Center(
                          child: CircularProgressIndicator(color: ec.orange)))
                else if (_error != null)
                  _ErrorCard(_error!)
                else ...[
                  const SizedBox(height: 20),
                  _buildKpis(),
                  const SizedBox(height: 24),
                  _buildChart(),
                  const SizedBox(height: 24),
                  if (_scanners.length > 1) ...[
                    _buildTeam(),
                    const SizedBox(height: 24),
                  ],
                  _buildActivity(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    final ec = context.ec;
    final rangeLabel =
        '${DateFormat('dd MMM', 'es').format(_desde)} – ${DateFormat('dd MMM yyyy', 'es').format(_hasta)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel('Panel de operaciones'),
          Text('Estadísticas',
              style: EnjoyTheme.heading(
                  size: 22, weight: FontWeight.w800, color: ec.text)),
          const SizedBox(height: 16),

          // Selector de rango
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: ec.glass,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ec.stroke),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, color: ec.orangeSoft, size: 16),
                        const SizedBox(width: 8),
                        Text(rangeLabel,
                            style: EnjoyTheme.body(
                                size: 13,
                                weight: FontWeight.w600,
                                color: ec.text)),
                        const Spacer(),
                        Icon(Icons.keyboard_arrow_down, color: ec.textMute, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderChip('Hoy', () => _quick(0)),
              const SizedBox(width: 6),
              _HeaderChip('7d', () => _quick(7)),
              const SizedBox(width: 6),
              _HeaderChip('30d', () => _quick(30)),
            ],
          ),
        ],
      ),
    );
  }

  // ── KPIs ──
  Widget _buildKpis() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: StatCard(
                    value: '$_total', label: 'Canjes totales')),
            const SizedBox(width: 12),
            Expanded(
                child: StatCard(
                    value: '$_hoy', label: 'Canjes hoy', accent: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                value: _promedio == 0 ? '—' : _promedio.toStringAsFixed(1),
                label: 'Promedio por día',
                valueSize: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                value: (_peak != null && _peak!.count > 0)
                    ? '${_peak!.count} el ${DateFormat('dd/MM').format(DateTime.parse(_peak!.fecha))}'
                    : '—',
                label: 'Mejor día',
                valueSize: 22,
              ),
            ),
          ],
        ),
        if (_ultimoEscaneo != null) ...[
          const SizedBox(height: 12),
          ListRowTile(
            leading: const IconBox(Icons.access_time_outlined),
            title: _ultimoEscaneo!,
            subtitle: 'Último canje registrado',
          ),
        ],
      ],
    );
  }

  // ── Gráfico ──
  Widget _buildChart() {
    final ec = context.ec;
    final days = _chartDays;
    final maxY = days.isEmpty ? 5.0 : days.map((d) => d.count.toDouble()).reduce((a, b) => a > b ? a : b);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Canjes por día',
                  style: EnjoyTheme.heading(size: 14, color: ec.text)),
              Text('Últimos 7 días',
                  style: EnjoyTheme.body(size: 11, color: ec.textMute)),
            ],
          ),
          const SizedBox(height: 16),
          days.isEmpty
              ? const _EmptyState('Sin canjes en el período')
              : SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: ec.stroke, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (maxY * 1.35).clamp(3, double.infinity),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 20,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= days.length) return const SizedBox.shrink();
                              return Text('${days[i].count}',
                                  style: EnjoyTheme.body(
                                      size: 11,
                                      weight: FontWeight.w800,
                                      color: ec.orangeSoft));
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= days.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  DateFormat('dd/MM').format(DateTime.parse(days[i].fecha)),
                                  style: EnjoyTheme.body(size: 10, color: ec.textMute),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: days.asMap().entries.map((e) {
                        final isToday = e.value.fecha == _fmt(_stripTime(DateTime.now()));
                        return BarChartGroupData(x: e.key, barRods: [
                          BarChartRodData(
                            toY: e.value.count.toDouble(),
                            width: 20,
                            borderRadius: BorderRadius.circular(5),
                            gradient: LinearGradient(
                              colors: isToday
                                  ? [ec.orangeSoft, ec.orange]
                                  : [
                                      ec.blue,
                                      ec.blue.withValues(alpha: 0.55)
                                    ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
          if (days.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Legend(color: ec.orange, label: 'Hoy'),
                  const SizedBox(width: 16),
                  _Legend(color: ec.blue, label: 'Días anteriores'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Equipo ──
  Widget _buildTeam() {
    final ec = context.ec;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rendimiento del equipo',
              style: EnjoyTheme.heading(size: 14, color: ec.text)),
          const SizedBox(height: 14),
          ..._scanners.asMap().entries.map((e) {
            final rank = e.key + 1;
            final p = e.value;
            final pct = _total > 0 ? p.count / _total : 0.0;
            final isTop = rank == 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isTop
                          ? ec.orange.withValues(alpha: 0.15)
                          : ec.glassStrong,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isTop ? ec.orange : ec.stroke,
                      ),
                    ),
                    child: Text('$rank',
                        style: EnjoyTheme.body(
                          size: 12,
                          weight: FontWeight.w800,
                          color: isTop ? ec.orangeSoft : ec.textMute,
                        )),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(p.nombre,
                                  style: EnjoyTheme.body(
                                      weight: FontWeight.w600,
                                      size: 13,
                                      color: ec.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text('${p.count} canje${p.count != 1 ? 's' : ''}',
                                style: EnjoyTheme.body(
                                    weight: FontWeight.w700,
                                    size: 12,
                                    color: ec.orangeSoft)),
                            const SizedBox(width: 4),
                            Text('· ${(pct * 100).toStringAsFixed(0)}%',
                                style: EnjoyTheme.body(
                                    size: 11, color: ec.textMute)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: ec.glassStrong,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isTop ? ec.orange : ec.orange.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Actividad reciente ──
  Widget _buildActivity() {
    final recientes = [..._raw]..sort((a, b) {
        final fa = DateTime.tryParse(a['fechaEscaneo'] ?? '') ?? DateTime(2000);
        final fb = DateTime.tryParse(b['fechaEscaneo'] ?? '') ?? DateTime(2000);
        return fb.compareTo(fa);
      });
    final top = recientes.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel('Actividad reciente'),
        if (top.isEmpty)
          const _EmptyState('Sin actividad en el período')
        else
          ...top.map((item) {
            final dt = DateTime.tryParse(item['fechaEscaneo'] ?? '')?.toLocal();
            final fechaStr = dt != null
                ? DateFormat('dd/MM · hh:mm a', 'es').format(dt)
                : '—';
            final cupon = item['cupon'];
            final sec = (cupon is Map) ? cupon['secuencial']?.toString() : '—';
            final ep = item['escaneadoPor'];
            final scanner = (ep is Map) ? (ep['nombre']?.toString() ?? '—') : '—';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListRowTile(
                leading: const IconBox(Icons.qr_code_2),
                title: 'Cupón #$sec',
                subtitle: scanner,
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Pill('Canjeado',
                        variant: PillVariant.green, dense: true),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) => Text(
                        fechaStr,
                        style: EnjoyTheme.body(
                            size: 11,
                            weight: FontWeight.w500,
                            color: context.ec.textMute),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ── Data models ──────────────────────────────────────────

class _DayData {
  final String fecha;
  final int count;
  const _DayData(this.fecha, this.count);
}

class _PersonData {
  final String nombre;
  final int count;
  const _PersonData(this.nombre, this.count);
}

// ── Shared widgets ────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _HeaderChip(this.text, this.onTap);

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: ec.glassStrong,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ec.stroke),
        ),
        child: Text(text,
            style: EnjoyTheme.body(
                size: 12, weight: FontWeight.w700, color: ec.textSoft)),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: EnjoyTheme.body(size: 11, color: ec.textMute)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState(this.msg);

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(msg, style: EnjoyTheme.body(size: 13, color: ec.textMute)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String msg;
  const _ErrorCard(this.msg);

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ec.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ec.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: ec.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: EnjoyTheme.body(size: 13, color: ec.red))),
        ],
      ),
    );
  }
}
