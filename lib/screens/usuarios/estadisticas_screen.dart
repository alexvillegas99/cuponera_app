import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:enjoy/ui/palette.dart';
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
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Palette.kAccent, secondary: Palette.kPrimary),
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
    return RefreshIndicator(
      onRefresh: _load,
      color: Palette.kPrimary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Header con gradiente ──
          SliverToBoxAdapter(child: _buildHeader()),

          // ── Contenido ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_loading)
                  const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: Palette.kAccent)))
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
    final rangeLabel =
        '${DateFormat('dd MMM', 'es').format(_desde)} – ${DateFormat('dd MMM yyyy', 'es').format(_hasta)}';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Palette.kPrimary, Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Panel de operaciones',
              style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Estadísticas',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          // Selector de rango
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(rangeLabel,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        const Spacer(),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
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
            Expanded(child: _KpiTile(value: '$_total', label: 'Canjes totales', icon: Icons.qr_code_scanner_outlined, color: Palette.kAccent)),
            const SizedBox(width: 12),
            Expanded(child: _KpiTile(value: '$_hoy', label: 'Canjes hoy', icon: Icons.today_outlined, color: Palette.kAccent)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                value: _promedio == 0 ? '—' : _promedio.toStringAsFixed(1),
                label: 'Promedio por día',
                icon: Icons.trending_up_outlined,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiTile(
                value: (_peak != null && _peak!.count > 0)
                    ? '${_peak!.count} el ${DateFormat('dd/MM').format(DateTime.parse(_peak!.fecha))}'
                    : '—',
                label: 'Mejor día',
                icon: Icons.emoji_events_outlined,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        if (_ultimoEscaneo != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Palette.kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.kBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Palette.kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.access_time_outlined, size: 16, color: Palette.kAccent),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Último canje registrado',
                        style: TextStyle(color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                    Text(_ultimoEscaneo!,
                        style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Gráfico ──
  Widget _buildChart() {
    final days = _chartDays;
    final maxY = days.isEmpty ? 5.0 : days.map((d) => d.count.toDouble()).reduce((a, b) => a > b ? a : b);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader('Canjes por día', Icons.bar_chart_outlined),
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
                            FlLine(color: Palette.kBorder, strokeWidth: 1),
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
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Palette.kAccent));
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
                                  style: const TextStyle(fontSize: 10, color: Palette.kMuted),
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
                                  ? [Palette.kAccent, Palette.kAccent.withOpacity(0.7)]
                                  : [const Color(0xFF8BA3C7), const Color(0xFF8BA3C7).withOpacity(0.55)],
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
                  _Legend(color: Palette.kAccent, label: 'Hoy'),
                  const SizedBox(width: 16),
                  _Legend(color: const Color(0xFF8BA3C7), label: 'Días anteriores'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Equipo ──
  Widget _buildTeam() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader('Rendimiento del equipo', Icons.groups_outlined),
          const SizedBox(height: 14),
          ..._scanners.asMap().entries.map((e) {
            final rank = e.key + 1;
            final p = e.value;
            final pct = _total > 0 ? p.count / _total : 0.0;
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
                      color: rank == 1
                          ? const Color(0xFFF59E0B).withOpacity(0.15)
                          : Palette.kBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: rank == 1 ? const Color(0xFFF59E0B) : Palette.kBorder,
                      ),
                    ),
                    child: Text('$rank',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: rank == 1 ? const Color(0xFFF59E0B) : Palette.kMuted,
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
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Palette.kTitle),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text('${p.count} canje${p.count != 1 ? 's' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Palette.kAccent)),
                            const SizedBox(width: 4),
                            Text('· ${(pct * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 11, color: Palette.kMuted)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: Palette.kBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              rank == 1 ? Palette.kAccent : Palette.kAccent.withOpacity(0.45),
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

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader('Actividad reciente', Icons.history_outlined),
          const SizedBox(height: 12),
          if (top.isEmpty)
            const _EmptyState('Sin actividad en el período')
          else
            ...top.asMap().entries.map((e) {
              final item = e.value;
              final isLast = e.key == top.length - 1;
              final dt = DateTime.tryParse(item['fechaEscaneo'] ?? '')?.toLocal();
              final fechaStr = dt != null
                  ? DateFormat('dd/MM · hh:mm a', 'es').format(dt)
                  : '—';
              final cupon = item['cupon'];
              final sec = (cupon is Map) ? cupon['secuencial']?.toString() : '—';
              final ep = item['escaneadoPor'];
              final scanner = (ep is Map) ? (ep['nombre']?.toString() ?? '—') : '—';

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Palette.kAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.qr_code_2, color: Palette.kAccent, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cupón #$sec',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Palette.kTitle)),
                              Text(scanner,
                                  style: const TextStyle(fontSize: 12, color: Palette.kMuted)),
                            ],
                          ),
                        ),
                        Text(fechaStr,
                            style: const TextStyle(fontSize: 11, color: Palette.kMuted, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(height: 1, color: Palette.kBorder),
                ],
              );
            }),
        ],
      ),
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _CardHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Palette.kAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Palette.kAccent),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Palette.kTitle)),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;

  const _KpiTile({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 11, color: Palette.kMuted, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color, height: 1)),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _HeaderChip(this.text, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
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
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Palette.kMuted)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState(this.msg);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(msg, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String msg;
  const _ErrorCard(this.msg);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        ],
      ),
    );
  }
}
