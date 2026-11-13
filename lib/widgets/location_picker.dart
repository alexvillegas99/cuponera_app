// lib/widgets/location_picker.dart
//
// Selector visual de provincia / ciudad. Reemplaza al `SearchablePickerField`
// genérico cuando queremos algo más amigable para el usuario final:
//   - Card grande tappeable con ícono + estado vacío descriptivo.
//   - Bottom sheet con:
//       · Buscador en vivo.
//       · Chips "Populares" arriba (ej. las 5 provincias más usadas en Ecuador).
//       · Lista completa con check en el seleccionado.
//   - Botón opcional "Usar mi ubicación" se delega afuera.

import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

typedef LocationItem = ({String id, String label});

class LocationPicker extends StatelessWidget {
  /// Etiqueta del campo (ej. "Provincia").
  final String label;

  /// Hint visible cuando no hay nada seleccionado.
  final String emptyHint;

  /// Ícono principal a la izquierda.
  final IconData icon;

  /// Item actualmente seleccionado (id). Null si no hay selección.
  final String? value;

  /// Lista completa de opciones.
  final List<LocationItem> items;

  /// IDs de las opciones "populares" — se muestran como chips arriba.
  /// Si está vacío, no se muestra la sección.
  final List<String> populares;

  /// Callback al seleccionar (o limpiar). null = quitar selección.
  final ValueChanged<String?> onChanged;

  /// Deshabilita el campo (útil mientras carga la lista).
  final bool disabled;

  const LocationPicker({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.emptyHint = 'Tocá para seleccionar',
    this.populares = const [],
    this.disabled = false,
  });

  String? get _selectedLabel {
    for (final i in items) {
      if (i.id == value) return i.label;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    if (disabled) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        label: label,
        items: items,
        value: value,
        populares: populares,
        icon: icon,
      ),
    );
    if (selected != null) {
      onChanged(selected == '__none__' ? null : selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final sel = _selectedLabel;
    final tieneSeleccion = sel != null;

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: ec.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tieneSeleccion ? ec.orange.withValues(alpha: 0.6) : ec.stroke,
            width: tieneSeleccion ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ec.orange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: ec.orange, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sel ?? emptyHint,
                    overflow: TextOverflow.ellipsis,
                    style: EnjoyTheme.heading(
                      size: 14.5,
                      weight: FontWeight.w700,
                      color: tieneSeleccion ? ec.text : ec.textMute,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (tieneSeleccion)
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: ec.textMute),
                onPressed: () => onChanged(null),
                tooltip: 'Quitar',
              )
            else
              Icon(Icons.chevron_right_rounded, color: ec.textMute, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet con buscador + chips populares + lista filtrable.
class _LocationPickerSheet extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<LocationItem> items;
  final List<String> populares;
  final String? value;

  const _LocationPickerSheet({
    required this.label,
    required this.icon,
    required this.items,
    required this.populares,
    required this.value,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LocationItem> get _filtered {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((it) => it.label.toLowerCase().contains(q))
        .toList();
  }

  List<LocationItem> get _populares {
    if (widget.populares.isEmpty) return const [];
    final byId = {for (final it in widget.items) it.id: it};
    return widget.populares
        .map((id) => byId[id])
        .whereType<LocationItem>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: ec.surfaceMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ec.strokeStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                Icon(widget.icon, color: ec.orange, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Elegí tu ${widget.label.toLowerCase()}',
                    style: EnjoyTheme.heading(
                      size: 18,
                      weight: FontWeight.w800,
                      color: ec.text,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: ec.textMute),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _q = v),
              autofocus: false,
              style: EnjoyTheme.body(color: ec.text),
              decoration: InputDecoration(
                hintText: 'Buscar…',
                prefixIcon: Icon(Icons.search, color: ec.textMute, size: 20),
                suffixIcon: _q.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: ec.textMute, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _q = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: ec.glass,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ec.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ec.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ec.orange, width: 1.5),
                ),
              ),
            ),
          ),

          // Populares — solo cuando no hay búsqueda activa
          if (_q.isEmpty && _populares.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, size: 14, color: ec.orange),
                  const SizedBox(width: 6),
                  Text(
                    'POPULARES',
                    style: EnjoyTheme.body(
                      size: 11,
                      color: ec.textMute,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _populares.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final it = _populares[i];
                  final activo = widget.value == it.id;
                  return InkWell(
                    onTap: () => Navigator.pop(context, it.id),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: activo
                            ? ec.orange
                            : ec.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: activo
                              ? ec.orange
                              : ec.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.place,
                              size: 14,
                              color: activo ? ec.onAccent : ec.orange),
                          const SizedBox(width: 6),
                          Text(
                            it.label,
                            style: EnjoyTheme.body(
                              size: 13,
                              weight: FontWeight.w700,
                              color: activo ? ec.onAccent : ec.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Icon(Icons.list_rounded, size: 14, color: ec.textMute),
                  const SizedBox(width: 6),
                  Text(
                    'TODOS (${widget.items.length})',
                    style: EnjoyTheme.body(
                      size: 11,
                      color: ec.textMute,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Lista filtrada
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off,
                              size: 36, color: ec.textMute),
                          const SizedBox(height: 10),
                          Text(
                            'Sin resultados para "$_q".',
                            textAlign: TextAlign.center,
                            style: EnjoyTheme.body(
                                size: 13.5, color: ec.textSoft),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final it = _filtered[i];
                      final activo = widget.value == it.id;
                      return Material(
                        color: activo
                            ? ec.orange.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, it.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            child: Row(
                              children: [
                                Icon(
                                  activo
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: activo ? ec.orange : ec.textMute,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    it.label,
                                    style: EnjoyTheme.heading(
                                      size: 14.5,
                                      weight: activo
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: activo ? ec.orange : ec.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
