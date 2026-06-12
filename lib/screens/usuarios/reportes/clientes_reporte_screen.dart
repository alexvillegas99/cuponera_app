import 'package:enjoy/services/reportes_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils/reportes_utils.dart';
import 'widgets/reportes_widgets.dart';

class ClientesReporteScreen extends StatefulWidget {
  const ClientesReporteScreen({super.key});

  @override
  State<ClientesReporteScreen> createState() => _ClientesReporteScreenState();
}

class _ClientesReporteScreenState extends State<ClientesReporteScreen> {
  final _svc = ReportesService();
  DateTime _desde = DateTime.now().subtract(const Duration(days: 90));
  DateTime _hasta = DateTime.now();
  bool _loading = true;
  Map<String, dynamic>? _data;

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
      final d = await _svc.clientes(r);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _porcRecurrentes() {
    final t = (_data?['recurrentes'] ?? 0) + (_data?['unicos'] ?? 0);
    if (t == 0) return 0;
    return (_data!['recurrentes'] as num) / t;
  }

  Future<void> _compartir() async {
    final rows = ((_data?['topClientes'] as List?) ?? [])
        .map((c) => {
              'nombre': '${c['nombres'] ?? ''} ${c['apellidos'] ?? ''}'.trim(),
              'email': c['email'] ?? '',
              'canjes': c['canjes'],
            })
        .toList();
    await shareCsv(
      'top-clientes',
      List<Map<String, dynamic>>.from(rows),
      const [
        (key: 'nombre', label: 'Cliente'),
        (key: 'email', label: 'Email'),
        (key: 'canjes', label: 'Canjes'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Clientes & Retención'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ReporteHeader(
            icon: Icons.people_rounded,
            title: 'Clientes & Retención',
            subtitle: 'Nuevos, recurrentes y top consumo',
            onCompartir: _data == null ? null : _compartir,
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
          if (_loading && _data == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: CircularProgressIndicator(color: ec.orange),
              ),
            )
          else if (_data != null) ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                StatKpi(
                    label: 'Total',
                    value: fmtN(_data!['totalClientes'])),
                StatKpi(
                  label: 'Nuevos',
                  value: fmtN(_data!['nuevosEnRango']),
                  accent: true,
                ),
                StatKpi(
                    label: 'Recurrentes',
                    value: fmtN(_data!['recurrentes'])),
                StatKpi(
                  label: '% recurrentes',
                  value: fmtPct(_porcRecurrentes(), digits: 0),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Top consumidores',
                style: EnjoyTheme.heading(size: 15, color: ec.text)),
            const SizedBox(height: 8),
            SimpleTable(
              headers: const ['Cliente', 'Canjes'],
              rows: ((_data!['topClientes'] as List?) ?? [])
                  .take(15)
                  .map<List<Widget>>(
                    (c) => [
                      Text(
                        '${c['nombres'] ?? ''} ${c['apellidos'] ?? ''}'.trim(),
                        style: EnjoyTheme.body(
                            size: 13,
                            color: ec.text,
                            weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        fmtN(c['canjes']),
                        style: EnjoyTheme.heading(size: 14, color: ec.orange),
                      ),
                    ],
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            if ((_data!['porProvincia'] as List?)?.isNotEmpty ?? false) ...[
              Text('Por provincia',
                  style: EnjoyTheme.heading(size: 15, color: ec.text)),
              const SizedBox(height: 8),
              SimpleTable(
                headers: const ['Provincia', 'Clientes'],
                rows: (_data!['porProvincia'] as List)
                    .take(15)
                    .map<List<Widget>>(
                      (p) => [
                        Text(
                          (p['provincia'] ?? '—').toString(),
                          style: EnjoyTheme.body(
                              size: 13,
                              color: ec.text,
                              weight: FontWeight.w600),
                        ),
                        Text(
                          fmtN(p['total']),
                          style: EnjoyTheme.heading(
                              size: 14, color: ec.blue),
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
