import 'package:flutter/material.dart';
import '../ui/palette.dart';
import '../services/auth_service.dart';

class GreetingCard extends StatefulWidget {
  final VoidCallback onViewProfile;
  const GreetingCard({super.key, required this.onViewProfile});

  @override
  State<GreetingCard> createState() => _GreetingCardState();
}

class _GreetingCardState extends State<GreetingCard> {
  final _auth = AuthService();
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
  final user = await _auth.getUser(); // Lee el usuario desde SecureStorage
  if (user != null) {
    setState(() {
      if (user['nombres'] != null) {
        // Caso cliente
        _userName = '${user['nombres']} ${user['apellidos'] ?? ''}'.trim();
      } else {
        // Caso usuario normal
        _userName = user['nombre'] ?? 'Invitado';
      }
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Bienvenido,',
                  style: TextStyle(color: Palette.kMuted, fontSize: 12),
                ),
                Text(
                  _userName ?? 'Invitado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: widget.onViewProfile,
            icon: const Icon(
              Icons.account_circle_outlined,
              size: 18,
              color: Palette.kPrimary,
            ),
            label: const Text(
              'Ver perfil',
              style: TextStyle(
                color: Palette.kPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
