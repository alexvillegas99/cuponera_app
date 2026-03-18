import 'package:flutter/material.dart';
import '../ui/palette.dart';

class CategoryTileLight extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const CategoryTileLight({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 90,
            minWidth: 90, // 👈 asegura cuadrado en grid
          ),
          decoration: BoxDecoration(
            color: selected
                ? Palette.kAccent.withOpacity(0.12)
                : Palette.kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Palette.kAccent : Palette.kBorder,
              width: selected ? 1.2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: selected ? Palette.kAccent : Palette.kMuted,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: selected ? Palette.kAccent : Palette.kTitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
