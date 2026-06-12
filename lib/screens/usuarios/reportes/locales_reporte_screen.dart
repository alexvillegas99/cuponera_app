import 'package:enjoy/services/reportes_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils/reportes_utils.dart';
import 'widgets/reportes_widgets.dart';

class LocalesReporteScreen extends StatefulWidget {
  const LocalesReporteScreen({super.key});

  @override
  State<LocalesReporteScreen> createState() => _LocalesReporteScreenState();
}

class _LocalesReporteScreenState extends State<LocalesReporteScreen> {
  final _svc = ReportesService();
  DateTime _desde = DateTime.now().subtract(const Duration(days: 90));
  DateTime _hasta = DateTime.now();
  bool _loading = true;

  Map<String, dynamic>? _locales;
  Map<String, dynamic>? _vendedores;

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
      final res = await Future.wait([
        _svc.locales(r, limit: 25),
        _svc.vendedores(r),
      ]);
      if (!mounted) return;
      setState(() {
        _locales = res[0];
        _vendedores = res[1];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compartir() async {
    final ranking = (_locales?['ranking'] as List?) ?? [];
    final rows = ranking
        .map((l) => {
              'nombre': l['nombre'],
              'ciudad': l['ciudad'],
              'estado': (l['estado'] == true) ? 'Activo' : 'Inactivo',
              'canjes': l['canjes'],
            })
        .toList();
    await shareCsv(
      'ranking-locales',
      List<Map<String, dynamic>>.from(rows),
      const [
        (key: 'nombre', label: 'Local'),
        (key: 'ciudad', label: 'Ciudad'),
        (key: 'estado', label: 'Estado'),
        (key: 'canjes', label: 'Canjes'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final ranking = ((_locales?['ranking'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final vendedores = ((_vendedores?['vendedores'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Locales & Vendedores'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ReporteHeader(
            icon: Icons.store_rounded,
            title: 'Locales & Vendedores',
            subtitle: 'Ranking + productividad por creador',
            onCompartir: _locales == null ? null : _compartir,
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
          if (_loading && _locales == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: CircularProgressIndicator(color: ec.orange),
              ),
            )
          else if (_locales != null) ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                StatKpi(label: 'Total', value: fmtN(_locales!['total'])),
                StatKpi(
                  label: 'Activos',
                  value: fmtN(_locales!['activos']),
                  accent: true,
                ),
                StatKpi(
                  label: 'Inactivos',
                  value: fmtN(_locales!['inactivos']),
                  valueColor: ec.textMute,
                ),
                StatKpi(
                  label: '% Activos',
                  value: ((_locales!['total'] ?? 0) > 0)
                      ? '${(((_locales!['activos'] ?? 0) / _locales!['total']) * 100).toStringAsFixed(0)}%'
                      : '0%',
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text('Ranking de locales',
                style: EnjoyTheme.heading(size: 15, color: ec.text)),
            const SizedBox(height: 8),
            SimpleTable(
              headers: const ['Local', 'Ciudad', 'Canjes'],
              rows: ranking
                  .take(15)
                  .map<List<Widget>>(
                    (l) => [
                      Text(
                        (l['nombre'] ?? '').toString(),
                        style: EnjoyTheme.body(
                            size: 12.5,
                            color: ec.text,
                            weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        (l['ciudad'] ?? '—').toString(),
                        style:
                            EnjoyTheme.body(size: 12, color: ec.textSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        fmtN(l['canjes']),
                        style:
                            EnjoyTheme.heading(size: 13, color: ec.orange),
                      ),
                    ],
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            Text('Productividad por creador',
                style: EnjoyTheme.heading(size: 15, color: ec.text)),
            const SizedBox(height: 8),
            for (final v in vendedores) ...[
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    EnjoyAvatar(
                      (v['nombre'] ?? 'C').toString(),
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (v['nombre'] ?? '').toString(),
                                  style: EnjoyTheme.heading(
                                      size: 13.5, color: ec.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Pill(
                                (v['rol'] ?? '—').toString(),
                                variant: PillVariant.glass,
                                dense: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _miniBadge(ec, 'Locales',
                                  fmtN(v['localesCreados'])),
                              const SizedBox(width: 6),
                              _miniBadge(ec, 'Activos', fmtN(v['activos'])),
                              const SizedBox(width: 6),
                              _miniBadge(
                                ec,
                                'Canjes',
                                fmtN(v['canjesGenerados']),
                                accent: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (vendedores.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('Sin creadores aún',
                      style: EnjoyTheme.body(color: ec.textMute)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _miniBadge(EnjoyColors ec, String label, String value,
      {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent ? ec.orange.withValues(alpha: 0.18) : ec.glass,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent
              ? ec.orange.withValues(alpha: 0.4)
              : ec.stroke,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: EnjoyTheme.body(
                size: 10,
                color: ec.textMute,
                weight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: EnjoyTheme.heading(
              size: 11.5,
              color: accent ? ec.orange : ec.text,
            ),
          ),
        ],
      ),
    );
  }
}
