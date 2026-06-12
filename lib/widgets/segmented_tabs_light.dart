import 'package:flutter/material.dart';
import '../ui/enjoy_dark.dart';
import '../ui/palette.dart';

class SegmentedTabsLight extends StatelessWidget {
  final TabController controller;
  const SegmentedTabsLight({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          color: ED.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ED.border),
        ),
        child: TabBar(
          controller: controller,
          labelPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Palette.kAccent, Palette.kAccentLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Palette.kAccent.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          labelColor: Colors.white,
          unselectedLabelColor: ED.mute,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_rounded, size: 15),
                  SizedBox(width: 5),
                  Text('Todas'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.today_rounded, size: 15),
                  SizedBox(width: 5),
                  Text('Hoy'),
                ],
              ),
            ),
            // Pestaña "Flash" deshabilitada temporalmente (no se usa por ahora).
            // Tab(
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Icon(Icons.bolt_rounded, size: 15),
            //       SizedBox(width: 5),
            //       Text('Flash'),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
