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
  bool _locked = false; // 🔒 evita múltiples solicitudes simultáneas
  final historicoService = HistoricoCuponService();
  final authService = AuthService();

  // ✅ Controlador persistente para poder detener/arrancar el escáner
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      // 👇 Usa uno u otro según tu versión de mobile_scanner:

      // v3+:
      // detectionSpeed: DetectionSpeed.noDuplicates,
      // detectionTimeoutMs: 1000,

      // v2.x:
      // formats: [BarcodeFormat.qrCode],
      // facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleQrDetected(String data) async {
    if (_locked) return; // ya hay una solicitud en curso
    _locked = true;

    // 🛑 Pausa de inmediato el escáner para que no haya más eventos
    await _controller.stop();

    try {
      final String cuponId = data.trim();

      final usuario = await authService.getUser();
      final usuarioId = usuario?['_id'];
      if (usuarioId == null) {
        throw Exception('No se pudo obtener el usuario autenticado');
      }

      final validacion = await historicoService.validarCuponPorId(
        id: cuponId,
        usuarioId: usuarioId,
      );
      if (!mounted) return;

      // Navega al resultado y espera la respuesta (true = registrado)
      final ok = await context.push<bool>('/qr-result', extra: validacion);
      if (!mounted) return;

      if (ok == true) {
        // Propaga éxito hacia atrás (CuponesScreen/Home recargan)
        Navigator.of(context).pop(true);
        return; // No reanudes: ya saliste de esta pantalla
      }

      // Si no se registró, puedes reanudar el escáner para intentar de nuevo
      await _controller.start();
    } catch (e) {
      if (!mounted) return;
      await showDialog(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20),
    contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red[50],
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.qr_code_2, color: Colors.red, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'QR no válido',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(height: 4),
        Text('El código escaneado no pertenece a ENJOY.'),
        SizedBox(height: 8),
        Text(
          'Verifica que el QR provenga de un cupón oficial de ENJOY (impreso o generado en la app) y vuelve a intentarlo.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    ),
    actions: [
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Color(0xFF398AE5), // tu primario
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('Intentar de nuevo', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    ],
  ),
);


      // Tras el error, reanuda el escáner para reintentar
      await _controller.start();
    } finally {
      _locked = false;
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
            controller: _controller,

            // 👇 Evita lecturas repetidas sin parar el stream (elige según versión):
            // v3+:
            // detectionSpeed: DetectionSpeed.noDuplicates,
            // detectionTimeoutMs: 1000,

            // v2.x:
            // allowDuplicates: false,

            onDetect: (capture) {
              if (capture.barcodes.isEmpty) return;
              final qr = capture.barcodes.first.rawValue;
              if (qr == null || qr.isEmpty) return;
              _handleQrDetected(qr);
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
