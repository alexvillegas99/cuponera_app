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

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Palette.kAccent : Palette.kField;
    final border = selected ? Palette.kAccent : Palette.kBorder;
    final text = selected ? Colors.white : Palette.kSub;
    final iconColor = selected ? Colors.white : Palette.kMuted;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22), border: Border.all(color: border)),
          child: Row(children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: text)),
          ]),
        ),
      ),
    );
  }
}
