import 'package:enjoy/services/reportes_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils/reportes_utils.dart';
import 'widgets/reportes_widgets.dart';

class FlashReporteScreen extends StatefulWidget {
  const FlashReporteScreen({super.key});

  @override
  State<FlashReporteScreen> createState() => _FlashReporteScreenState();
}

class _FlashReporteScreenState extends State<FlashReporteScreen> {
  final _svc = ReportesService();
  DateTime _desde = DateTime.now().subtract(const Duration(days: 90));
  DateTime _hasta = DateTime.now();
  bool _loading = true;

  Map<String, dynamic>? _flash;
  Map<String, dynamic>? _solicitudes;

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
        _svc.flash(r),
        _svc.solicitudes(r),
      ]);
      if (!mounted) return;
      setState(() {
        _flash = res[0];
        _solicitudes = res[1];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compartir() async {
    final rows = ((_flash?['topFlash'] as List?) ?? [])
        .map((f) => {
              'titulo': f['titulo'],
              'local': f['local'],
              'estado': f['estado'],
              'vistas': f['vistas'],
              'canjes': f['canjes'],
            })
        .toList();
    await shareCsv(
      'top-flash',
      List<Map<String, dynamic>>.from(rows),
      const [
        (key: 'titulo', label: 'Título'),
        (key: 'local', label: 'Local'),
        (key: 'estado', label: 'Estado'),
        (key: 'vistas', label: 'Vistas'),
        (key: 'canjes', label: 'Canjes'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Flash & Solicitudes'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ReporteHeader(
            icon: Icons.bolt_rounded,
            title: 'Flash & Solicitudes',
            subtitle: 'Conversión flash y embudo de solicitudes',
            onCompartir: _flash == null ? null : _compartir,
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
          if (_loading && _flash == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: CircularProgressIndicator(color: ec.orange),
              ),
            )
          else ...[
            if (_flash != null) ...[
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: ec.orange, size: 18),
                  const SizedBox(width: 6),
                  Text('Promos flash',
                      style: EnjoyTheme.heading(size: 15, color: ec.text)),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  StatKpi(label: 'Creadas', value: fmtN(_flash!['totalFlash'])),
                  StatKpi(
                      label: 'Canjes',
                      value: fmtN(_flash!['canjes']),
                      accent: true),
                  StatKpi(label: 'Vistas', value: fmtN(_flash!['vistas'])),
                  StatKpi(
                    label: 'Conversión',
                    value: fmtPct(
                        (_flash!['tasaConversion'] as num?)?.toDouble() ?? 0),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Top promos flash',
                  style: EnjoyTheme.heading(size: 15, color: ec.text)),
              const SizedBox(height: 8),
              SimpleTable(
                headers: const ['Título', 'Local', 'Canjes'],
                rows: ((_flash!['topFlash'] as List?) ?? [])
                    .take(10)
                    .map<List<Widget>>(
                      (f) => [
                        Text(
                          (f['titulo'] ?? '').toString(),
                          style: EnjoyTheme.body(
                              size: 12.5,
                              color: ec.text,
                              weight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          (f['local'] ?? '—').toString(),
                          style:
                              EnjoyTheme.body(size: 12, color: ec.textSoft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          fmtN(f['canjes']),
                          style:
                              EnjoyTheme.heading(size: 13, color: ec.orange),
                        ),
                      ],
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            if (_solicitudes != null) ...[
              Row(
                children: [
                  Icon(Icons.account_balance_rounded,
                      color: ec.blue, size: 18),
                  const SizedBox(width: 6),
                  Text('Solicitudes de cuponera',
                      style: EnjoyTheme.heading(size: 15, color: ec.text)),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  StatKpi(
                      label: 'Recibidas',
                      value: fmtN(_solicitudes!['total'])),
                  StatKpi(
                    label: 'Tiempo aprob.',
                    value:
                        '${((_solicitudes!['tiempoPromedioHoras'] as num?) ?? 0).toStringAsFixed(1)} h',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SimpleTable(
                headers: const ['Estado', 'Total'],
                rows: ((_solicitudes!['porEstado'] as List?) ?? [])
                    .map<List<Widget>>(
                      (s) => [
                        Text(
                          (s['estado'] ?? '—').toString(),
                          style: EnjoyTheme.body(
                              size: 12.5,
                              color: ec.text,
                              weight: FontWeight.w600),
                        ),
                        Text(
                          fmtN(s['total']),
                          style:
                              EnjoyTheme.heading(size: 13, color: ec.blue),
                        ),
                      ],
                    )
                    .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
