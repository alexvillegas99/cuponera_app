import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:enjoy/state/server_health_store.dart';
import 'package:enjoy/ui/palette.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<ServerHealthStore>();
    return Scaffold(
      backgroundColor: Palette.kBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Palette.kSurface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 30,
                        color: Colors.black.withOpacity(0.15),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.build_rounded,
                    size: 54,
                    color: Palette.kTitle,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Estamos en mantenimiento',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Palette.kTitle,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  health.message ?? 'Pronto retomaremos el servicio. Gracias por tu paciencia.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Palette.kSub, height: 1.4),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.kPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => context.read<ServerHealthStore>().checkNow(),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
