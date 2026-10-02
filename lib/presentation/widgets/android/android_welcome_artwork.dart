import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Decorative route illustration, not a preview of a user's trip.
class AndroidWelcomeArtwork extends StatelessWidget {
  const AndroidWelcomeArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 300),
        child: AspectRatio(
          aspectRatio: 1.2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.surface, c.ground],
                ),
              ),
              child: CustomPaint(painter: _RoutePainter(c)),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final WandererColors colors;
  const _RoutePainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 300);
    final contour = Paint()
      ..color = colors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 7; i++) {
      final offset = i * 20.0;
      canvas.drawPath(
        Path()
          ..moveTo(-80 + offset, -30)
          ..cubicTo(200 + offset, 30, -60 + offset, 110, 110 + offset, 190)
          ..cubicTo(230 + offset, 250, 110 + offset, 320, 230 + offset, 340),
        contour,
      );
    }
    canvas.drawOval(
      const Rect.fromLTWH(224, 30, 112, 90),
      Paint()..color = colors.trailSoftBg.withValues(alpha: 0.65),
    );
    final route = Path()
      ..moveTo(68, 232)
      ..cubicTo(60, 185, 166, 215, 152, 164)
      ..cubicTo(140, 124, 89, 147, 114, 106)
      ..cubicTo(145, 55, 217, 143, 277, 78);
    canvas.drawPath(
        route,
        Paint()
          ..color = colors.surface
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 13);
    canvas.drawPath(
        route,
        Paint()
          ..color = WandererTheme.trail
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5);
    for (final point in [const Offset(68, 232), const Offset(152, 164)]) {
      canvas.drawCircle(point, 7, Paint()..color = colors.surface);
      canvas.drawCircle(
          point,
          5,
          Paint()
            ..color = WandererTheme.trail
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    canvas.drawCircle(const Offset(277, 78), 25,
        Paint()..color = WandererTheme.trail.withValues(alpha: 0.12));
    canvas.drawCircle(
        const Offset(277, 78), 15, Paint()..color = WandererTheme.trail);
    final arrow = Path()
      ..moveTo(270, 84)
      ..lineTo(277, 68)
      ..lineTo(284, 84)
      ..lineTo(277, 80)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) => oldDelegate.colors != colors;
}
