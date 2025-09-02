import 'dart:async';
import 'package:flutter/material.dart';
import 'pill_light.dart';

class FlashCountdownLight extends StatefulWidget {
  final DateTime endAt;
  const FlashCountdownLight({super.key, required this.endAt});

  @override
  State<FlashCountdownLight> createState() => _FlashCountdownLightState();
}

class _FlashCountdownLightState extends State<FlashCountdownLight> {
  late Timer _timer;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _left = widget.endAt.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = widget.endAt.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _left = diff.isNegative ? Duration.zero : diff);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(_left.inHours);
    final m = two(_left.inMinutes % 60);
    final s = two(_left.inSeconds % 60);
    return PillLight(label: '$h:$m:$s', icon: Icons.flash_on);
  }
}
