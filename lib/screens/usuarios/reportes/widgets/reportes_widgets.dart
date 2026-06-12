import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Card KPI compacta. Hereda el look de GlassCard.
class StatKpi extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  final Color? valueColor;
  const StatKpi({
    super.key,
    required this.label,
    required this.value,
    this.accent = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GlassCard(
      accent: accent,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: EnjoyTheme.body(
              size: 10.5,
              color: ec.textMute,
              weight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: EnjoyTheme.heading(
              size: 22,
              color: valueColor ?? ec.text,
              letterSpacing: -0.02,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque para filtros de fecha + botón actualizar.
class FiltrosFecha extends StatelessWidget {
  final DateTime desde;
  final DateTime hasta;
  final ValueChanged<DateTime> onDesde;
  final ValueChanged<DateTime> onHasta;
  final VoidCallback onActualizar;
  final bool loading;

  const FiltrosFecha({
    super.key,
    required this.desde,
    required this.hasta,
    required this.onDesde,
    required this.onHasta,
    required this.onActualizar,
    this.loading = false,
  });

  Future<DateTime?> _pick(BuildContext context, DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dateButton(
                  context,
                  label: 'Desde',
                  text: fmt.format(desde),
                  onTap: () async {
                    final d = await _pick(context, desde);
                    if (d != null) onDesde(d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateButton(
                  context,
                  label: 'Hasta',
                  text: fmt.format(hasta),
                  onTap: () async {
                    final d = await _pick(context, hasta);
                    if (d != null) onHasta(d);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: EnjoyButton(
              label: 'Actualizar',
              icon: Icons.refresh_rounded,
              loading: loading,
              onPressed: loading ? null : onActualizar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(
    BuildContext context, {
    required String label,
    required String text,
    required VoidCallback onTap,
  }) {
    final ec = context.ec;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ec.glass,
          border: Border.all(color: ec.stroke),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: EnjoyTheme.body(
                size: 10,
                color: ec.textMute,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: ec.orange),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: EnjoyTheme.heading(size: 13, color: ec.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Header común con icono naranja + título + subtítulo + botón compartir CSV.
class ReporteHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onCompartir;

  const ReporteHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onCompartir,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Row(
      children: [
        IconBox(icon, accent: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: EnjoyTheme.heading(size: 18, color: ec.text)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: EnjoyTheme.body(size: 12, color: ec.textMute)),
            ],
          ),
        ),
        if (onCompartir != null)
          GlassIconButton(
            icon: Icons.ios_share_rounded,
            onTap: onCompartir,
          ),
      ],
    );
  }
}

/// Renderiza una tabla simple con texto plano (no scroll horizontal).
/// Para datasets pequeños y resumidos.
class SimpleTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  const SimpleTable({super.key, required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Container(
      decoration: BoxDecoration(
        color: ec.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ec.stroke),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                for (int i = 0; i < headers.length; i++)
                  Expanded(
                    flex: i == 0 ? 3 : 2,
                    child: Text(
                      headers[i].toUpperCase(),
                      textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                      style: EnjoyTheme.body(
                        size: 10,
                        color: ec.textMute,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (int r = 0; r < rows.length; r++) ...[
            Container(height: 1, color: ec.stroke),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  for (int i = 0; i < rows[r].length; i++)
                    Expanded(
                      flex: i == 0 ? 3 : 2,
                      child: Align(
                        alignment: i == 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: rows[r][i],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Sin datos en el período',
                textAlign: TextAlign.center,
                style: EnjoyTheme.body(color: ec.textMute),
              ),
            ),
        ],
      ),
    );
  }
}
