import 'package:dio/dio.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/promociones_flash_service.dart';

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

  /// Devuelve true si [s] es un ObjectId de 24 chars hex (formato Mongo) — el
  /// formato de los cupones de Enjoy. Sirve para filtrar QRs random ANTES de
  /// pegarle al back, así no confundimos "sin red" con "QR de otra app".
  bool _esObjectIdValido(String s) {
    if (s.length != 24) return false;
    return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(s);
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

      // 🔶 Promoción flash: "flash:<promocionId>:<clienteId>"
      if (cuponId.startsWith('flash:')) {
        await _validarFlash(cuponId);
        return;
      }

      // Filtro local: si el QR no tiene formato de cupón Enjoy (ObjectId Mongo)
      // tampoco le pegamos al back. Así diferenciamos "QR de otra app" de
      // "el back está caído o sin red" más adelante en el catch.
      if (!_esObjectIdValido(cuponId)) {
        throw _NoEsCuponEnjoyException();
      }

      final usuario = await authService.getUser();
      final rol = usuario?['rol']?.toString().toLowerCase();
      final esStaff = rol == 'staff';
      final escaneadoPorId = usuario?['_id']?.toString(); // siempre el logueado real
      // Para validación y anti-duplicado: staff envía el id de su admin-local
      final usuarioId = esStaff
          ? (usuario?['usuarioCreacion']?.toString())
          : escaneadoPorId;
      debugPrint('[QR] rol: $rol | esStaff: $esStaff | usuarioId: $usuarioId | escaneadoPor: $escaneadoPorId');
      if (esStaff && (usuarioId == null || usuarioId.isEmpty)) {
        throw Exception(
            'Tu cuenta de staff no tiene un local asignado. Pídele al admin del local que te re-asigne.');
      }
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

      // Distinguir 3 casos para no confundir al usuario:
      //  1) Sin red / timeout → "Sin conexión"
      //  2) QR no es de Enjoy (no tiene formato de ObjectId) → "QR no válido"
      //  3) Back rechazó por una razón específica → mostrar mensaje del back
      String errorMsg = 'El código escaneado no pertenece a ENJOY.';
      String errorDetail =
          'Verifica que el QR provenga de un cupón oficial de ENJOY (impreso o generado en la app) y vuelve a intentarlo.';

      if (e is _NoEsCuponEnjoyException) {
        // case (2)
        errorMsg = 'Este QR no es un cupón de ENJOY';
        errorDetail =
            'El código que escaneaste no tiene el formato de un cupón de la app. Si crees que es un error, pídele al cliente que lo regenere desde la app.';
      } else if (e is DioException) {
        final esErrorRed = e.response == null ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        if (esErrorRed) {
          // case (1)
          errorMsg = 'Sin conexión';
          errorDetail =
              'No pudimos comunicarnos con el servidor de ENJOY. Verifica tu internet o WiFi del local y vuelve a intentarlo.';
        } else {
          final data = e.response?.data;
          final backendMsg =
              data is Map ? (data['message'] ?? data['error']) : null;
          if (backendMsg != null && backendMsg.toString().isNotEmpty) {
            // case (3)
            errorMsg = backendMsg.toString();
            errorDetail = '';
          }
        }
      } else if (e is Exception) {
        // Otros errores con mensaje propio (p.ej. staff sin local asignado).
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.isNotEmpty && !msg.contains('Exception')) {
          errorMsg = msg;
          errorDetail = '';
        }
      }

      final ec = context.ec;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              IconBox(Icons.qr_code_2_rounded, color: ec.red, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'QR no válido',
                  style: EnjoyTheme.heading(size: 18, color: ec.text),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(errorMsg,
                  style: EnjoyTheme.body(size: 14, color: ec.textSoft)),
              if (errorDetail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  errorDetail,
                  style: EnjoyTheme.body(size: 13, color: ec.textMute),
                ),
              ],
            ],
          ),
          actions: [
            EnjoyButton(
              label: 'Intentar de nuevo',
              expand: false,
              dense: true,
              onPressed: () => Navigator.of(ctx).pop(),
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

  /// Valida el canje de una promoción flash escaneada (QR del cliente).
  Future<void> _validarFlash(String qrData) async {
    final ec = context.ec;
    try {
      final res = await PromocionesFlashService().validar(qrData);
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: ec.surfaceTop,
          title: Row(
            children: [
              IconBox(Icons.check_circle_rounded, color: ec.green, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text('¡Promoción validada!',
                    style: EnjoyTheme.heading(size: 18, color: ec.text)),
              ),
            ],
          ),
          content: Text(
            (res['titulo'] ?? 'Canje registrado correctamente.').toString(),
            style: EnjoyTheme.body(size: 14, color: ec.textSoft),
          ),
          actions: [
            EnjoyButton(
              label: 'Continuar',
              expand: false,
              dense: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = 'No se pudo validar la promoción.';
      if (e is DioException) {
        final data = e.response?.data;
        final backendMsg = data is Map ? (data['message'] ?? data['error']) : null;
        if (backendMsg != null && backendMsg.toString().isNotEmpty) {
          msg = backendMsg.toString();
        }
      }
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: ec.surfaceTop,
          title: Row(
            children: [
              IconBox(Icons.error_outline_rounded, color: ec.red, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Canje no válido',
                    style: EnjoyTheme.heading(size: 18, color: ec.text)),
              ),
            ],
          ),
          content: Text(msg,
              style: EnjoyTheme.body(size: 14, color: ec.textSoft)),
          actions: [
            EnjoyButton(
              label: 'Entendido',
              expand: false,
              dense: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    const frameSize = 260.0;
    final ec = context.ec;

    return Scaffold(
      backgroundColor: ec.bgBottom,
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

          // ── Overlay oscuro con hueco centrado ──
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
                  // Marco de escaneo del DS, exactamente sobre el hueco
                  Positioned(
                    left: cx - half,
                    top: cy - half,
                    width: frameSize,
                    height: frameSize,
                    child: const ScanFrame(size: frameSize),
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
                const SizedBox(height: 36),
                Text(
                  'Apunta al código QR del cupón',
                  textAlign: TextAlign.center,
                  style: EnjoyTheme.body(
                      size: 14, weight: FontWeight.w500, color: ec.textSoft),
                ),
                const Spacer(),
                // Card de ayuda glass
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: GlassCard(
                    color: ec.surfaceMid.withValues(alpha: .82),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: ec.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Si el código no pertenece a ENJOY verás "QR no válido".',
                            style: EnjoyTheme.body(
                                size: 12, color: ec.textSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: GestureDetector(
                    onTap: () => _controller.toggleTorch(),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: ec.glassStrong,
                        shape: BoxShape.circle,
                        border: Border.all(color: ec.strokeStrong),
                      ),
                      child: Icon(Icons.flash_on_rounded,
                          color: ec.text, size: 24),
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
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          // Botón volver
          BackChip(onTap: () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Text(
            'Escanear cupón',
            style: EnjoyTheme.heading(size: 17, color: ec.text),
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
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);
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

/// Excepción interna del flujo de escaneo: el contenido del QR no tiene
/// el formato de un cupón de Enjoy (un ObjectId Mongo de 24 chars hex).
/// Permite distinguirlo de errores de red.
class _NoEsCuponEnjoyException implements Exception {
  const _NoEsCuponEnjoyException();
}
