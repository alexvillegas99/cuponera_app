import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:enjoy/ui/enjoy_colors.dart';
import 'package:enjoy/ui/enjoy_theme.dart';

/// Ítem del dock inferior.
class DockItem {
  const DockItem({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

/// Dock inferior flotante de vidrio con FAB central (`.dock`).
///
/// Recibe los ítems de la izquierda y de la derecha del FAB. El FAB central
/// es opcional (`onFab`); si es null, se reparten los ítems sin botón central.
class EnjoyDock extends StatelessWidget {
  const EnjoyDock({
    super.key,
    required this.items,
    required this.currentIndex,
    this.onFab,
    this.fabIcon = Icons.add,
  });

  final List<DockItem> items;
  final int currentIndex;
  final VoidCallback? onFab;
  final IconData fabIcon;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final hasFab = onFab != null;
    final mid = (items.length / 2).floor();

    // Fila de ítems; deja un hueco central para el FAB (que se dibuja encima).
    final rowChildren = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (hasFab && i == mid) {
        rowChildren.add(const SizedBox(width: 72));
      }
      rowChildren.add(_DockTile(item: items[i], active: i == currentIndex));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: SizedBox(
        height: 66,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Barra de vidrio (recortada/desenfocada)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: ec.surfaceMid
                          .withValues(alpha: ec.isDark ? .86 : .96),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: ec.stroke),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .35),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                          spreadRadius: -16,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: rowChildren,
                    ),
                  ),
                ),
              ),
            ),
            // FAB central, dibujado por encima (sin recortar).
            if (hasFab)
              Positioned(
                top: -20,
                left: 0,
                right: 0,
                child: Center(child: _Fab(icon: fabIcon, onTap: onFab!)),
              ),
          ],
        ),
      ),
    );
  }
}

class _DockTile extends StatelessWidget {
  const _DockTile({required this.item, required this.active});
  final DockItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final color = active ? ec.orangeSoft : ec.textMute;
    return Expanded(
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 20, color: color),
            const SizedBox(height: 5),
            Text(item.label,
                style: EnjoyTheme.body(
                    size: 10, weight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Fab extends StatefulWidget {
  const _Fab({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // Anillo del color del fondo de pantalla → el FAB se "recorta" de la
          // barra y resalta frente a otros elementos naranjas/amarillos.
          return Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: ec.bgBottom,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: ec.accentGradient,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .30),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ec.orange.withValues(alpha: .55 + .25 * _c.value),
                    blurRadius: 28 + 6 * _c.value,
                    offset: const Offset(0, 12),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(widget.icon, color: ec.onAccent, size: 28),
            ),
          );
        },
      ),
    );
  }
}
