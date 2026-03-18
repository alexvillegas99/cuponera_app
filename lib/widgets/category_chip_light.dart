import 'dart:math';
import 'package:flutter/material.dart';
import '../ui/palette.dart';

class CategoryChipLight extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChipLight({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  // 🎨 Color pastel determinístico por label
  Color _pastelFromLabel(String input) {
    final hash = input.codeUnits.fold(0, (a, b) => a + b);
    final rnd = Random(hash);

    // tonos suaves
    final h = rnd.nextDouble() * 360;
    final s = 0.35; // baja saturación
    final l = 0.90; // alto brillo

    return HSLColor.fromAHSL(1, h, s, l).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final pastel = _pastelFromLabel(label);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 88,
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? Palette.kAccent.withOpacity(0.18)
                    : pastel, // 👈 color suave automático
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? Palette.kAccent : pastel.withOpacity(0.6),
                  width: selected ? 1.2 : 1,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: selected ? Palette.kAccent : Palette.kTitle,
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color:
                            selected ? Palette.kAccent : Palette.kTitle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
