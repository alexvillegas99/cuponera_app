import 'package:flutter/material.dart';
import '../ui/palette.dart';

class GreetingCard extends StatelessWidget {
  final String name;
  final VoidCallback onViewProfile;
  const GreetingCard({super.key, required this.name, required this.onViewProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: const Color(0xFFE9E5FF), child: const Icon(Icons.person, color: Color(0xFF7C6CF4))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('¡Bienvenido,', style: TextStyle(color: Palette.kMuted, fontSize: 12)),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ]),
          ),
          TextButton.icon(
            onPressed: onViewProfile,
            icon: const Icon(Icons.account_circle_outlined, size: 18, color: Palette.kPrimary),
            label: const Text('Ver perfil', style: TextStyle(color: Palette.kPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
