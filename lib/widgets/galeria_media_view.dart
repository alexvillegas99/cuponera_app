import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:enjoy/ui/widgets/enjoy_image.dart';
import '../models/media_item.dart';

/// Carrusel de galería del local para el detalle del cliente.
/// Por defecto muestra las imágenes primero; si hay video, se reproduce
/// en autoplay silenciado (muted) con un botón para activar el audio.
class GaleriaMediaView extends StatefulWidget {
  final List<MediaItem> items;
  final double height;

  const GaleriaMediaView({super.key, required this.items, this.height = 220});

  @override
  State<GaleriaMediaView> createState() => _GaleriaMediaViewState();
}

class _GaleriaMediaViewState extends State<GaleriaMediaView> {
  final _controller = PageController();
  int _index = 0;

  /// Imágenes primero, videos después.
  List<MediaItem> get _ordered {
    final imgs = widget.items.where((m) => !m.isVideo).toList();
    final vids = widget.items.where((m) => m.isVideo).toList();
    return [...imgs, ...vids];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _ordered;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _controller,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final m = items[i];
                if (m.isVideo) {
                  return _MutedAutoplayVideo(url: m.url);
                }
                return EnjoyImage(
                  m.url,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: const Color(0xFFEDEFF5),
                    child: const Icon(Icons.broken_image_rounded,
                        color: Colors.grey, size: 40),
                  ),
                );
              },
            ),
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? Theme.of(context).primaryColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Versión full-bleed del carrusel para el FONDO (hero) del detalle del local.
/// Llena todo el espacio (BoxFit.cover, sin bordes redondeados), muestra las
/// imágenes primero y el video en autoplay silenciado con botón de audio.
class GaleriaHeroView extends StatefulWidget {
  final List<MediaItem> items;
  final String? fallbackImageUrl;

  const GaleriaHeroView({super.key, required this.items, this.fallbackImageUrl});

  @override
  State<GaleriaHeroView> createState() => _GaleriaHeroViewState();
}

class _GaleriaHeroViewState extends State<GaleriaHeroView> {
  final _controller = PageController();
  int _index = 0;
  Timer? _autoTimer;

  /// En el hero el VIDEO va primero (se reproduce al entrar); luego las imágenes.
  List<MediaItem> get _ordered {
    final vids = widget.items.where((m) => m.isVideo).toList();
    final imgs = widget.items.where((m) => !m.isVideo).toList();
    return [...vids, ...imgs];
  }

  bool get _hasVideo => widget.items.any((m) => m.isVideo);

  @override
  void initState() {
    super.initState();
    _maybeStartAutoScroll();
  }

  /// Auto-scroll de imágenes. Si hay video NO se auto-pasa: el cliente desliza.
  void _maybeStartAutoScroll() {
    final count = _ordered.length;
    if (_hasVideo || count <= 1) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _fallback() {
    if ((widget.fallbackImageUrl ?? '').isNotEmpty) {
      return EnjoyImage(widget.fallbackImageUrl!, fit: BoxFit.cover,
          errorWidget: Container(color: const Color(0xFFD9DEEA)));
    }
    return Container(color: const Color(0xFFD9DEEA));
  }

  @override
  Widget build(BuildContext context) {
    final items = _ordered;
    if (items.isEmpty) return _fallback();

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) {
            final m = items[i];
            if (m.isVideo) return _MutedAutoplayVideo(url: m.url);
            return EnjoyImage(
              m.url,
              fit: BoxFit.cover,
              errorWidget: _fallback(),
            );
          },
        ),
        // Indicadores (arriba, debajo del status bar, para no chocar con el logo/nombre)
        if (items.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 52,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// Video que arranca en autoplay silenciado, en loop, con botón de audio.
class _MutedAutoplayVideo extends StatefulWidget {
  final String url;
  const _MutedAutoplayVideo({required this.url});

  @override
  State<_MutedAutoplayVideo> createState() => _MutedAutoplayVideoState();
}

class _MutedAutoplayVideoState extends State<_MutedAutoplayVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = c;
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0); // silenciado por defecto
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  void _toggleAudio() {
    final c = _controller;
    if (c == null) return;
    setState(() => _muted = !_muted);
    c.setVolume(_muted ? 0 : 1);
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (!_ready || c == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            const Center(
              child: Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white70, size: 56),
            ),
          // Botón de audio (centro-derecha, fuera de los degradados para que se vea)
          Align(
            alignment: const Alignment(0.92, -0.10),
            child: GestureDetector(
              onTap: _toggleAudio,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: _muted ? 12 : 10, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.62),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white70, width: 1.2),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    if (_muted) ...[
                      const SizedBox(width: 6),
                      const Text('Sonido',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
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
