import 'package:flutter/material.dart';
import '../ui/enjoy_colors.dart';

/// Botón de filtro por provincia/ciudad de la cabecera. Mismo estilo que la
/// campana (neutro); el número de provincias elegidas va en una insignia
/// discreta en el tono secundario del tema (no en el acento).
class CityFilterIcon extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const CityFilterIcon({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final active = count > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: 'Filtrar por ciudad',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ec.glass,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: ec.stroke),
              ),
              child: Icon(
                Icons.location_city_rounded,
                size: 19,
                color: active ? ec.secondaryDeep : ec.textSoft,
              ),
            ),
          ),
        ),
        if (active)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: ec.secondaryDeep,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: ec.bgBottom, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: ec.isDark ? const Color(0xFF1D1E21) : Colors.white,
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
