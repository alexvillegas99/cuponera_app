import 'package:flutter/material.dart';
import '../ui/palette.dart';

class SegmentedTabsLight extends StatelessWidget {
  final TabController controller;
  const SegmentedTabsLight({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: Palette.kField,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.kBorder),
        ),
        child: TabBar(
          controller: controller,
          labelPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          indicatorSize: TabBarIndicatorSize.tab,
          // 🔑 Quitar la línea inferior
          indicatorColor: Colors.transparent,
          indicator: BoxDecoration(
            color: Palette.kAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Palette.kMuted,
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Hoy'),
            Tab(text: 'Flash'),
          ],
        ),
      ),
    );
  }
}
