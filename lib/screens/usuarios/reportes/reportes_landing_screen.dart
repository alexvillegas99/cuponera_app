import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

import 'canjes_reporte_screen.dart';
import 'locales_reporte_screen.dart';
import 'clientes_reporte_screen.dart';
import 'flash_reporte_screen.dart';

class ReportesLandingScreen extends StatelessWidget {
  final bool embedded;
  const ReportesLandingScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;

    final items = [
      _Item(
        icon: Icons.trending_up_rounded,
        title: 'Canjes & Ingresos',
        subtitle: 'Tendencia de canjes, top locales y métodos de pago.',
        builder: () => const CanjesReporteScreen(),
      ),
      _Item(
        icon: Icons.store_rounded,
        title: 'Locales & Vendedores',
        subtitle: 'Ranking de locales y productividad por creador.',
        builder: () => const LocalesReporteScreen(),
      ),
      _Item(
        icon: Icons.people_rounded,
        title: 'Clientes & Retención',
        subtitle: 'Nuevos vs recurrentes, top consumidores, geografía.',
        builder: () => const ClientesReporteScreen(),
      ),
      _Item(
        icon: Icons.bolt_rounded,
        title: 'Flash & Solicitudes',
        subtitle: 'Promos flash y embudo de solicitudes.',
        builder: () => const FlashReporteScreen(),
      ),
    ];

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Row(
          children: [
            const IconBox(Icons.bar_chart_rounded, accent: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reportes',
                      style: EnjoyTheme.heading(size: 22, color: ec.text)),
                  const SizedBox(height: 2),
                  Text('Métricas y exportables — todo en un solo lugar',
                      style:
                          EnjoyTheme.body(size: 12.5, color: ec.textMute)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (final it in items) ...[
          GlassCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => it.builder()),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconBox(it.icon, accent: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.title,
                          style:
                              EnjoyTheme.heading(size: 15, color: ec.text)),
                      const SizedBox(height: 4),
                      Text(it.subtitle,
                          style: EnjoyTheme.body(
                              size: 12.5, color: ec.textMute, height: 1.4)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: ec.textMute),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );

    if (embedded) return content;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Reportes'),
      body: content,
    );
  }
}

class _Item {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function() builder;
  _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}
