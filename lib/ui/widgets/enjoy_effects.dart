import 'package:flutter/material.dart';

import 'package:enjoy/ui/enjoy_colors.dart';

/// Halo radial de fondo (los glow naranja/azul del `body`).
class GlowHalo extends StatelessWidget {
  const GlowHalo({super.key, required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Brillo diagonal que recorre el CTA naranja (animación `shine`).
class ShineSweep extends StatefulWidget {
  const ShineSweep({super.key});

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // Recorre de -1.3 a 2.6 con una pausa al final (como el CSS).
          final t = Curves.easeInOut.transform((_c.value / 0.6).clamp(0.0, 1.0));
          final x = -1.3 + t * 3.9;
          return FractionallySizedBox(
            widthFactor: 0.5,
            alignment: Alignment(x, 0),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(-0.32),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: .55),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Punto que parpadea con halo (animación `blink`).
class BlinkDot extends StatefulWidget {
  const BlinkDot({super.key, required this.color, this.size = 7});
  final Color color;
  final double size;

  @override
  State<BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<BlinkDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.55 + 0.45 * _c.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: .6 * (1 - _c.value)),
                blurRadius: 6 * _c.value,
                spreadRadius: 4 * _c.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pulso de glow expansivo alrededor de un hijo (animación `pulseGlow`).
class PulseGlow extends StatefulWidget {
  const PulseGlow({
    super.key,
    required this.child,
    this.color,
    this.radius = 999,
  });
  final Widget child;
  final Color? color;
  final double radius;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.ec.orange;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .55 * (1 - _c.value)),
                spreadRadius: 9 * _c.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Marco de escaneo con esquinas y línea que recorre (animaciones `scan`).
class ScanFrame extends StatefulWidget {
  const ScanFrame({super.key, this.size = 220});
  final double size;

  @override
  State<ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    const corner = 42.0;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Esquina superior izquierda
          Positioned(
            top: 0,
            left: 0,
            child: _corner(ec.orange, top: true, left: true, corner: corner),
          ),
          // Esquina inferior derecha
          Positioned(
            bottom: 0,
            right: 0,
            child: _corner(ec.orange, top: false, left: false, corner: corner),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final y = 8 + (_c.value * (widget.size - 16));
              return Positioned(
                top: y,
                left: 8,
                right: 8,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(colors: [
                      ec.orange.withValues(alpha: 0),
                      ec.orange,
                      ec.orange.withValues(alpha: 0),
                    ]),
                    boxShadow: [
                      BoxShadow(
                        color: ec.orange.withValues(alpha: .7),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _corner(Color color,
      {required bool top, required bool left, required double corner}) {
    return Container(
      width: corner,
      height: corner,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: color, width: 3) : BorderSide.none,
          bottom: !top ? BorderSide(color: color, width: 3) : BorderSide.none,
          left: left ? BorderSide(color: color, width: 3) : BorderSide.none,
          right: !left ? BorderSide(color: color, width: 3) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(18) : Radius.zero,
          bottomRight:
              !top && !left ? const Radius.circular(18) : Radius.zero,
        ),
      ),
    );
  }
}

/// Anima la entrada (fade + slide up), equivalente a `rise`.
class RiseIn extends StatelessWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.durationMs = 600,
  });
  final Widget child;
  final int delayMs;
  final int durationMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: durationMs + delayMs),
      curve: Interval(
        delayMs / (durationMs + delayMs),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child),
      ),
      child: child,
    );
  }
}
