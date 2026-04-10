import 'package:dio/dio.dart';
import 'package:enjoy/ui/palette.dart';
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
      debugPrint('[QR] Raw scanned value: "$data"');
      debugPrint('[QR] cuponId trimmed: "$cuponId"');

      final usuario = await authService.getUser();
      final rol = usuario?['rol']?.toString().toLowerCase();
      final esStaff = rol == 'staff';
      final escaneadoPorId = usuario?['_id']?.toString(); // siempre el logueado real
      // Para validación y anti-duplicado: staff envía el id de su admin-local
      final usuarioId = esStaff
          ? (usuario?['usuarioCreacion']?.toString())
          : escaneadoPorId;
      debugPrint('[QR] rol: $rol | esStaff: $esStaff | usuarioId: $usuarioId | escaneadoPor: $escaneadoPorId');
      if (usuarioId == null || escaneadoPorId == null) {
        throw Exception('No se pudo obtener el usuario autenticado');
      }

      debugPrint('[QR] Llamando validarCuponPorId id=$cuponId usuarioId=$usuarioId');
      final validacion = await historicoService.validarCuponPorId(
        id: cuponId,
        usuarioId: usuarioId,
      );
      // Pasar escaneadoPorId al result screen para el registro
      validacion['_escaneadoPorId'] = escaneadoPorId;
      debugPrint('[QR] Respuesta validacion: $validacion');
      if (!mounted) return;

      // Navega al resultado y espera el item registrado (Map) o null
      final newItem = await context.push<Map<String, dynamic>>('/qr-result', extra: validacion);
      if (!mounted) return;

      if (newItem != null) {
        // Propaga el item hacia CuponesScreen para inserción local sin reconsulta
        context.pop(newItem);
        return;
      }

      // Si no se registró, puedes reanudar el escáner para intentar de nuevo
      await _controller.start();
    } catch (e) {
      debugPrint('[QR] EXCEPCION: $e');
      if (e is DioException) {
        debugPrint('[QR] DioException status: ${e.response?.statusCode}');
        debugPrint('[QR] DioException data: ${e.response?.data}');
        debugPrint('[QR] DioException message: ${e.message}');
      }
      if (!mounted) return;

      // Extraer mensaje del backend si viene en una DioException
      String errorMsg = 'El código escaneado no pertenece a ENJOY.';
      String errorDetail = 'Verifica que el QR provenga de un cupón oficial de ENJOY (impreso o generado en la app) y vuelve a intentarlo.';
      if (e is DioException) {
        final data = e.response?.data;
        final backendMsg = data is Map ? (data['message'] ?? data['error']) : null;
        if (backendMsg != null && backendMsg.toString().isNotEmpty) {
          errorMsg = backendMsg.toString();
          errorDetail = '';
        }
      }

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
      children: [
        const SizedBox(height: 4),
        Text(errorMsg),
        if (errorDetail.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            errorDetail,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ],
    ),
    actions: [
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF9F1C),
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
    const frameSize = 260.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Cámara ──────────────────────────────────────────
          MobileScanner(
            fit: BoxFit.cover,
            controller: _controller,
            onDetect: (capture) {
              if (capture.barcodes.isEmpty) return;
              final qr = capture.barcodes.first.rawValue;
              if (qr == null || qr.isEmpty) return;
              _handleQrDetected(qr);
            },
          ),

          // ── Overlay + esquinas alineados con LayoutBuilder ──
          LayoutBuilder(
            builder: (_, constraints) {
              final cx = constraints.maxWidth / 2;
              final cy = constraints.maxHeight / 2;
              final half = frameSize / 2;

              return Stack(
                children: [
                  // Fondo oscuro con hueco centrado
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _OverlayPainter(
                      cx: cx, cy: cy, frameSize: frameSize),
                  ),
                  // Esquinas naranjas, exactamente sobre el hueco
                  Positioned(
                    left: cx - half,
                    top: cy - half,
                    width: frameSize,
                    height: frameSize,
                    child: _ScanFrame(size: frameSize),
                  ),
                ],
              );
            },
          ),

          // ── UI superpuesta ───────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const Spacer(),
                // Espacio del frame (ya posicionado en LayoutBuilder)
                const SizedBox(height: frameSize),
                const SizedBox(height: 72),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_2_rounded,
                          color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Apunta al código QR del cupón',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: GestureDetector(
                    onTap: () => _controller.toggleTorch(),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.flash_on_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          // Botón volver
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 4),
          // Logo + título
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: const LinearGradient(
                      colors: [Palette.kAccent, Palette.kAccentLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.local_activity_rounded,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Escanear cupón',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overlay oscuro con hueco central ─────────────────────────────

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter(
      {required this.cx, required this.cy, required this.frameSize});
  final double cx, cy, frameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.62);
    final half = frameSize / 2;
    const r = 20.0;

    final outer =
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half),
        const Radius.circular(r),
      ));
    canvas.drawPath(
        Path.combine(PathOperation.difference, outer, hole), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Marco con esquinas + línea de escaneo ────────────────────────

class _ScanFrame extends StatefulWidget {
  const _ScanFrame({required this.size});
  final double size;

  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scan;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scan = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          // Esquinas naranjas (líneas rectas)
          CustomPaint(
            size: Size(s, s),
            painter: const _CornerPainter(
              color: Palette.kAccent,
              strokeWidth: 4,
              cornerLength: 32,
            ),
          ),
          // Línea de escaneo animada
          AnimatedBuilder(
            animation: _scan,
            builder: (_, __) => Positioned(
              top: 10 + _scan.value * (s - 20),
              left: 14,
              right: 14,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Palette.kAccent.withOpacity(0.95),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.kAccent.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Painter de esquinas (líneas rectas, sin arcos) ────────────────

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
  });

  final Color color;
  final double strokeWidth;
  final double cornerLength;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final cl = cornerLength;

    // Top-left
    canvas.drawLine(Offset(0, cl), const Offset(0, 0), p);
    canvas.drawLine(const Offset(0, 0), Offset(cl, 0), p);
    // Top-right
    canvas.drawLine(Offset(w - cl, 0), Offset(w, 0), p);
    canvas.drawLine(Offset(w, 0), Offset(w, cl), p);
    // Bottom-left
    canvas.drawLine(Offset(0, h - cl), Offset(0, h), p);
    canvas.drawLine(Offset(0, h), Offset(cl, h), p);
    // Bottom-right
    canvas.drawLine(Offset(w - cl, h), Offset(w, h), p);
    canvas.drawLine(Offset(w, h - cl), Offset(w, h), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
