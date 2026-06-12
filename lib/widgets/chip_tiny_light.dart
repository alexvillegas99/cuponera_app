import 'package:flutter/material.dart';
import '../ui/enjoy_dark.dart';
import '../ui/palette.dart';

class ChipTinyLight extends StatelessWidget {
  final String label;
  const ChipTinyLight(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ED.field,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ED.border),
      ),
      child: Text(
        label,
        style: const TextStyle(color: ED.mute),
      ),
    );
  }
}
