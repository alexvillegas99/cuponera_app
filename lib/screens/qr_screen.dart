import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool isProcessing = false;
  bool canScan = true;

  void _handleQrDetected(String data) async {
  if (!canScan || isProcessing) return;
  setState(() {
    isProcessing = true;
    canScan = false;
  });

  await Future.delayed(const Duration(milliseconds: 500)); // simula procesamiento

  if (!mounted) return;

  // 🔄 Simular parseo del contenido del QR
  final qrData = {
    'numero': 1,
    'fechaInicio': '2025-07-01',
    'fechaFin': '2025-07-31',
    'usuario': 'Jonathan Parra',
    'fechaEscaneo': DateTime.now().toString().substring(0, 16),
  };

  if (mounted) {
    context.push(
      '/qr-result',
      extra: qrData, // Pasa los datos del QR al siguiente screen
    );

    setState(() {
      isProcessing = false;
    });

    await Future.delayed(const Duration(seconds: 2));
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
            icon: const Icon(Icons.arrow_back, color: Color(0xFFF4F1DE), size: 28),
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
