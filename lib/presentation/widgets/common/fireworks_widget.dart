import 'dart:math';
import 'package:flutter/material.dart';

/// A fullscreen fireworks animation widget.
///
/// Spawns colourful firework bursts at random positions. Each burst fans out
/// particles that fade, shrink, and fall with gravity. Works on web and mobile
/// because it only uses Flutter's [CustomPainter] canvas API.
class FireworksWidget extends StatefulWidget {
  /// Number of simultaneous bursts on screen.
  final int burstCount;

  /// Duration between successive new bursts.
  final Duration burstInterval;

  const FireworksWidget({
    super.key,
    this.burstCount = 6,
    this.burstInterval = const Duration(milliseconds: 600),
  });

  @override
  State<FireworksWidget> createState() => _FireworksWidgetState();
}

class _FireworksWidgetState extends State<FireworksWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Burst> _bursts = [];
  final Random _rng = Random();
  double _timeSinceLastBurst = 0;

  static const List<Color> _palette = [
    Color(0xFFFF4444),
    Color(0xFFFFAA00),
    Color(0xFF44FF44),
    Color(0xFF44AAFF),
    Color(0xFFFF44FF),
    Color(0xFFFFFF44),
    Color(0xFFFF8800),
    Color(0xFF00FFCC),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _controller.repeat();
  }

  void _tick() {
    const dt = 1.0 / 60.0; // ~60 fps
    _timeSinceLastBurst += dt;

    final intervalSec = widget.burstInterval.inMilliseconds / 1000.0;
    if (_timeSinceLastBurst >= intervalSec) {
      _timeSinceLastBurst = 0;
      _spawnBurst();
    }

    // Remove dead bursts
    _bursts.removeWhere((b) => b.isDead);

    for (final burst in _bursts) {
      burst.update(dt);
    }

    setState(() {});
  }

  void _spawnBurst() {
    // Random position within 80 % of centre to avoid edges
    final size = MediaQuery.of(context).size;
    final x = size.width * (0.1 + _rng.nextDouble() * 0.8);
    final y = size.height * (0.15 + _rng.nextDouble() * 0.5);
    final color = _palette[_rng.nextInt(_palette.length)];
    _bursts.add(_Burst(origin: Offset(x, y), color: color, rng: _rng));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FireworksPainter(bursts: _bursts),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal models
// ---------------------------------------------------------------------------

class _Burst {
  final List<_Particle> particles;
  static const int _particleCount = 40;
  static const double _lifetime = 1.6; // seconds

  _Burst({
    required Offset origin,
    required Color color,
    required Random rng,
  }) : particles = List.generate(_particleCount, (_) {
          final angle = rng.nextDouble() * 2 * pi;
          final speed = 120.0 + rng.nextDouble() * 260.0;
          final life = 0.8 + rng.nextDouble() * (_lifetime - 0.8);
          // Slight colour variation per particle
          final hsl = HSLColor.fromColor(color);
          final tweaked = hsl
              .withLightness(
                  (hsl.lightness + (rng.nextDouble() - 0.5) * 0.2).clamp(0, 1))
              .withSaturation((hsl.saturation + (rng.nextDouble() - 0.5) * 0.15)
                  .clamp(0, 1))
              .toColor();
          return _Particle(
            x: origin.dx,
            y: origin.dy,
            vx: cos(angle) * speed,
            vy: sin(angle) * speed,
            color: tweaked,
            radius: 2.0 + rng.nextDouble() * 2.5,
            maxLife: life,
          );
        });

  bool get isDead => particles.every((p) => p.life >= p.maxLife);

  void update(double dt) {
    for (final p in particles) {
      p.update(dt);
    }
  }
}

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  final Color color;
  final double radius;
  final double maxLife;
  double life = 0;

  static const double _gravity = 180; // px/s²
  static const double _drag = 0.98;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.radius,
    required this.maxLife,
  });

  double get progress => (life / maxLife).clamp(0, 1);

  void update(double dt) {
    if (life >= maxLife) return;
    life += dt;
    vx *= _drag;
    vy *= _drag;
    vy += _gravity * dt;
    x += vx * dt;
    y += vy * dt;
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _FireworksPainter extends CustomPainter {
  final List<_Burst> bursts;

  _FireworksPainter({required this.bursts});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final burst in bursts) {
      for (final p in burst.particles) {
        if (p.life >= p.maxLife) continue;
        final opacity = (1.0 - p.progress).clamp(0.0, 1.0);
        final r = p.radius * (1.0 - p.progress * 0.5);
        paint.color = p.color.withOpacity(opacity);
        canvas.drawCircle(Offset(p.x, p.y), r, paint);

        // Tiny glow
        paint.color = p.color.withOpacity(opacity * 0.3);
        canvas.drawCircle(Offset(p.x, p.y), r * 2.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) => true;
}
