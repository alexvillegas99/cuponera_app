import 'package:flutter/material.dart';
import '../ui/palette.dart';

class CityFilterIcon extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const CityFilterIcon({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: 'Filtrar por ciudad',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: active
                    ? Palette.kAccent.withOpacity(0.09)
                    : Palette.kPrimary.withOpacity(0.09),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? Palette.kAccent.withOpacity(0.25)
                      : Palette.kPrimary.withOpacity(0.18),
                ),
              ),
              child: Icon(
                Icons.location_city_rounded,
                size: 18,
                color: active ? Palette.kAccent : Palette.kPrimary,
              ),
            ),
          ),
        ),
        if (active)
          Positioned(
            right: -5,
            top: -5,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Palette.kAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
