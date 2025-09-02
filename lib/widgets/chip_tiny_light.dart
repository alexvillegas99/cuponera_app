import 'package:flutter/material.dart';
import '../ui/palette.dart';

class ChipTinyLight extends StatelessWidget {
  final String label;
  const ChipTinyLight(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Palette.kField,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Palette.kBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Palette.kMuted),
      ),
    );
  }
}
