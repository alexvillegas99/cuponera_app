import 'package:flutter/material.dart';
import '../ui/palette.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem({required this.icon, required this.label});
}

class FloatingBottomBarLight extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const FloatingBottomBarLight({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = const [
      NavItem(icon: Icons.home_filled, label: 'Inicio'),
      NavItem(icon: Icons.favorite, label: 'Favoritos'),
      NavItem(icon: Icons.search, label: 'Buscar'),
      NavItem(icon: Icons.qr_code_2, label: 'Cuponeras'), // renombrado
    ];
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (int i = 0; i < items.length; i++)
            _NavButtonLight(item: items[i], active: i == index, onTap: () => onTap(i)),
        ],
      ),
    );
  }
}

class _NavButtonLight extends StatelessWidget {
  final NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavButtonLight({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Palette.kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active ? [BoxShadow(color: Palette.kAccent.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Row(children: [
          Icon(item.icon, color: active ? Colors.white : Palette.kSub, size: 22),
          if (active) ...[
            const SizedBox(width: 6),
            Text(item.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ]
        ]),
      ),
    );
  }
}
