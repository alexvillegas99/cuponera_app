import 'dart:ui';

import 'package:flutter/material.dart';

class BlurIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const BlurIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.black.withOpacity(0.35),
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
