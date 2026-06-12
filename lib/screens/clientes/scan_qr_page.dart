// lib/screens/clientes/scan_qr_page.dart
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  bool _done = false; // para evitar múltiples pops

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Scaffold(
      backgroundColor: const Color(0xFF02060D),
      body: Stack(
        children: [
          // ── Cámara mobile_scanner a pantalla completa ──
          Positioned.fill(
            child: MobileScanner(
              onDetect: (capture) {
                if (_done) return;
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;
                final raw = barcodes.first.rawValue ?? '';
                if (raw.isEmpty) return;
                _done = true;
                Navigator.pop(context, raw);
              },
            ),
          ),

          // ── Velo oscuro para legibilidad del overlay ──
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Guía de escaneo + texto de ayuda ──
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ScanFrame(size: 260),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: Text(
                    'Apunta al código QR de tu membresía',
                    textAlign: TextAlign.center,
                    style: EnjoyTheme.body(
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── AppBar flotante: back glass + título ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  BackChip(onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  Text(
                    'Escanear membresía',
                    style: EnjoyTheme.heading(size: 17, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // ── Card de ayuda inferior ──
          Positioned(
            left: 18,
            right: 18,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: GlassCard(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderColor: ec.strokeStrong,
                  padding: const EdgeInsets.all(14),
                  radius: 18,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: ec.orangeSoft),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El código debe pertenecer a una membresía Enjoy.',
                          style: EnjoyTheme.body(
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
