import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/ui/enjoy.dart';

/// Pantalla puente al cambiar de cuenta. Garantiza que el home destino se
/// reconstruya aunque sea la MISMA ruta que la anterior (p.ej. admin-local →
/// admin, ambos van a /home y GoRouter no recargaría sin este paso).
class SwitchingScreen extends StatefulWidget {
  const SwitchingScreen({super.key});

  @override
  State<SwitchingScreen> createState() => _SwitchingScreenState();
}

class _SwitchingScreenState extends State<SwitchingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = await AuthService().getTargetHomeRoute();
      if (mounted) context.go(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      body: Center(child: CircularProgressIndicator(color: ec.orange)),
    );
  }
}
