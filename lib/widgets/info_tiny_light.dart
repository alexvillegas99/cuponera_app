import 'package:flutter/material.dart';
import '../ui/palette.dart';

class InfoTinyLight extends StatelessWidget {
  final IconData icon;
  final String label;
  const InfoTinyLight({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Palette.kMuted, size: 16),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Palette.kSub)),
    ]);
  }
}
