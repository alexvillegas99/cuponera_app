import 'package:flutter/material.dart';
import '../ui/palette.dart';

class CitiesSheet extends StatelessWidget {
  final List<String> cities;
  final Set<String> selected;
  final void Function(String city, bool value) onToggle;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const CitiesSheet({
    super.key,
    required this.cities,
    required this.selected,
    required this.onToggle,
    required this.onClear,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Filtrar por ciudades',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Palette.kTitle,
            ),
          ),
          const SizedBox(height: 6),

          // Listado de ciudades con checkboxes
          ...cities.map((c) => CheckboxListTile(
                value: selected.contains(c),
                onChanged: (v) => onToggle(c, v ?? false), // <-- requerido
                activeColor: Palette.kAccent,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  c,
                  style: const TextStyle(color: Palette.kTitle),
                ),
              )),

          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: onClear,
                child: const Text('Limpiar', style: TextStyle(color: Palette.kMuted)),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.kAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onApply,
                child: const Text('Aplicar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
