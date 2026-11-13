// lib/screens/usuarios/selfie_liveness_screen.dart
//
// Selfie con prueba de vida en tiempo real usando `face_camera`.
//
// Flujo:
//   1. Abre cámara frontal con preview en vivo.
//   2. Desafíos en orden:
//        a) "Mirá al frente" → cara centrada y wellPositioned
//        b) "Sonreí"        → smilingProbability > 0.7
//        c) "Cerrá los ojos"→ leftEye + rightEye < 0.25
//   3. Al completar los 3 desafíos, captura automática y vuelve con base64.
//
// Si el usuario cancela, devuelve null.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enjoy/ui/enjoy.dart';
import 'package:face_camera/face_camera.dart';
import 'package:flutter/material.dart';

enum _Reto { centrar, mover }

extension on _Reto {
  String get etiqueta {
    switch (this) {
      case _Reto.centrar:
        return 'Mirá al frente';
      case _Reto.mover:
        return 'Movéte ←  →';
    }
  }

  String get descripcion {
    switch (this) {
      case _Reto.centrar:
        return 'Centrá tu rostro en el círculo.';
      case _Reto.mover:
        return 'Girá la cabeza a la izquierda y después a la derecha.';
    }
  }
}

class SelfieLivenessScreen extends StatefulWidget {
  const SelfieLivenessScreen({super.key});

  @override
  State<SelfieLivenessScreen> createState() => _SelfieLivenessScreenState();
}

class _SelfieLivenessScreenState extends State<SelfieLivenessScreen> {
  late FaceCameraController _controller;

  // Estado de los desafíos
  final List<_Reto> _retos = const [_Reto.centrar, _Reto.mover];
  int _idx = 0;
  bool _retoOk = false;
  bool _capturado = false;

  // Tracking del rango de ángulo Y para detectar movimiento.
  double? _minY;
  double? _maxY;
  static const _rangoMovimientoMin = 25.0; // grados de delta para "moverse"

  // Preview de la foto capturada antes de confirmar.
  String? _previewBase64;
  File? _previewFile;

  // Cuenta regresiva antes de la captura (para que la persona vuelva al centro).
  Timer? _countdownTimer;
  int _countdown = 0; // 0 = no countdown activo

  /// Después de N segundos en el mismo reto sin detectar, mostrar botón "Saltar".
  Timer? _skipTimer;
  bool _mostrarSkip = false;
  static const _segundosParaSkip = 5;

  @override
  void initState() {
    super.initState();
    _controller = FaceCameraController(
      autoCapture: false,
      defaultCameraLens: CameraLens.front,
      imageResolution: ImageResolution.medium,
      performanceMode: FaceDetectorMode.fast,
      // CRÍTICO: sin audio. Por defecto face_camera crea el CameraController
      // con enableAudio=true, lo que en iOS obliga a pedir permiso de micrófono
      // (NSMicrophoneUsageDescription). Si falta, iOS BLOQUEA la sesión de
      // cámara y la app se congela al abrir la selfie. Una selfie no necesita
      // audio, así que lo apagamos y evitamos por completo el problema.
      enableAudio: false,
      onCapture: _onCapture,
      onFaceDetected: _onFaceDetected,
    );
    _armarSkipTimer();
  }

  void _armarSkipTimer() {
    _skipTimer?.cancel();
    setState(() => _mostrarSkip = false);
    _skipTimer = Timer(const Duration(seconds: _segundosParaSkip), () {
      if (mounted) setState(() => _mostrarSkip = true);
    });
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Llamado por face_camera cada vez que detecta (o pierde) un rostro.
  void _onFaceDetected(Face? face) {
    if (_capturado) return;
    if (face == null) return;

    final reto = _retos[_idx];
    bool paso = false;
    final y = face.headEulerAngleY ?? 0;

    switch (reto) {
      case _Reto.centrar:
        // Cara presente y bien centrada (no de perfil).
        paso = y.abs() < 12;
        break;
      case _Reto.mover:
        // Tracking del rango de ángulo Y: al rotar la cabeza acumulamos min/max,
        // y cuando el delta supera el umbral, contamos como movimiento real.
        _minY = (_minY == null) ? y : (y < _minY! ? y : _minY);
        _maxY = (_maxY == null) ? y : (y > _maxY! ? y : _maxY);
        final delta = (_maxY ?? 0) - (_minY ?? 0);
        paso = delta >= _rangoMovimientoMin;
        break;
    }

    if (paso) {
      _avanzarReto();
    }
  }

  Future<void> _avanzarReto() async {
    if (_capturado || _retoOk) return;
    setState(() => _retoOk = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (_idx + 1 < _retos.length) {
      setState(() {
        _idx++;
        _retoOk = false;
        // Reset del tracking de movimiento al cambiar de paso.
        _minY = null;
        _maxY = null;
      });
      _armarSkipTimer();
    } else {
      // Pasó los retos → iniciar cuenta regresiva de 3s para que la persona
      // vuelva al centro antes de la captura (sin esto, la foto sale de perfil).
      _iniciarCountdownYCapturar();
    }
  }

  void _iniciarCountdownYCapturar() {
    _countdownTimer?.cancel();
    setState(() {
      _capturado = true;
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
        _controller.captureImage();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _onCapture(File? file) async {
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      // Pausamos el stream para que la cámara no siga consumiendo recursos
      // mientras el usuario decide. Si pide "Repetir", lo reanudamos.
      try {
        await _controller.stopImageStream();
      } catch (_) {}
      setState(() {
        _previewBase64 = b64;
        _previewFile = file;
      });
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context, null);
    }
  }

  Future<void> _aceptarFoto() async {
    if (_previewBase64 == null) return;
    Navigator.pop(context, _previewBase64);
  }

  Future<void> _repetirFoto() async {
    setState(() {
      _previewBase64 = null;
      _previewFile = null;
      _idx = 0;
      _retoOk = false;
      _capturado = false;
      _minY = null;
      _maxY = null;
    });
    try {
      await _controller.startImageStream();
    } catch (_) {}
    _armarSkipTimer();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;

    // Pantalla de preview: la foto capturada + aceptar / repetir.
    if (_previewFile != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context, null),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        '¿Te gusta cómo saliste?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Foto
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(
                      _previewFile!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
              // Botones
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: EnjoyButton(
                        label: 'Tomar otra',
                        icon: Icons.refresh,
                        variant: EnjoyButtonVariant.ghost,
                        onPressed: _repetirFoto,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnjoyButton(
                        label: 'Usar esta foto',
                        icon: Icons.check_circle_outline,
                        onPressed: _aceptarFoto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Cámara con overlay de face_camera (incluye círculo de detección)
          Positioned.fill(
            child: SmartFaceCamera(
              controller: _controller,
              showCaptureControl: false,
              showFlashControl: false,
              showCameraLensControl: false,
              indicatorShape: IndicatorShape.circle,
              indicatorAssetImage: null,
              messageBuilder: (context, detected) {
                if (detected == null || detected.face == null) {
                  return _hint('No vemos tu rostro — centralo en el círculo.', ec);
                }
                if (!detected.wellPositioned) {
                  return _hint('Acercate y centrate.', ec);
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // Barra de progreso arriba
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: List.generate(_retos.length, (i) {
                final activo = i <= _idx;
                final completado = i < _idx || (i == _idx && _retoOk);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 5,
                    decoration: BoxDecoration(
                      color: completado
                          ? ec.green
                          : activo
                              ? ec.orange
                              : Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Cerrar
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context, null),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),

          // Cuenta regresiva grande en el centro
          if (_countdown > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                      border: Border.all(color: ec.orange, width: 4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_countdown',
                      style: TextStyle(
                        color: ec.orange,
                        fontSize: 84,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Reto actual abajo
          Positioned(
            left: 16,
            right: 16,
            bottom: 30 + MediaQuery.of(context).padding.bottom,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Paso ${_idx + 1} de ${_retos.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _countdown > 0
                        ? 'Mirá al frente'
                        : _capturado
                            ? 'Capturando…'
                            : _retoOk
                                ? '¡Bien! ✓'
                                : _retos[_idx].etiqueta,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _countdown > 0
                        ? 'Quedate quieto, vamos a tomar la foto…'
                        : _retos[_idx].descripcion,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  if (_mostrarSkip && !_capturado && !_retoOk) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _avanzarReto,
                      icon: const Icon(Icons.skip_next,
                          color: Colors.white, size: 18),
                      label: const Text(
                        'Saltar este paso',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint(String t, EnjoyColors ec) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
}
