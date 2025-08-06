import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:enjoy/services/auth_service.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool isProcessing = false;
  bool canScan = true;

  final historicoService = HistoricoCuponService();
  final authService = AuthService();

void _handleQrDetected(String data) async {
  if (!canScan || isProcessing) return;

  setState(() {
    isProcessing = true;
    canScan = false;
  });

  try {
    // Espera un JSON en el QR con al menos el campo "id"
 
    final String cuponId = data.trim();

    // Obtener el usuario actual
    final usuario = await authService.getUser();
    final usuarioId = usuario?['_id'];

    if (usuarioId == null) {
      throw Exception('No se pudo obtener el usuario autenticado');
    }

    // Validar el cupón
    final Map<String, dynamic> validacion =
        await historicoService.validarCuponPorId(
      id: cuponId,
      usuarioId: usuarioId,
    );

    if (!mounted) return;


    // Navegar al resultado
    context.push(
      '/qr-result',
      extra: validacion,
    );
  } catch (e) {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error al validar cupón'),
        content: Text(e.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  if (mounted) {
    setState(() => isProcessing = false);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => canScan = true);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          MobileScanner(
            fit: BoxFit.cover,
            controller: MobileScannerController(),
            onDetect: (capture) {
              if (capture.barcodes.isNotEmpty) {
                final qr = capture.barcodes.first.rawValue;
                if (qr != null) {
                  _handleQrDetected(qr);
                }
              }
            },
          ),

          // Capa UI
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const Spacer(),
                _buildScannerFrame(),
                const SizedBox(height: 16),
                const Text(
                  'Alinea el código QR dentro del marco',
                  style: TextStyle(
                    color: Color(0xFFF4F1DE),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          if (isProcessing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFFF4F1DE),
              size: 28,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Escanear QR',
            style: TextStyle(
              color: Color(0xFFF4F1DE),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerFrame() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF4F1DE), width: 4),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
