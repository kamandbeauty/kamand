import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart' show RadialGradient;

import '../decor/persian_motifs.dart';

/// جشنِ بردنِ دست — موجِ نور + شمسهٔ بازشونده + جرقه‌های طلایی.
///
/// سه لایه که با هم اجرا می‌شوند:
/// ۱) شاک‌ویوِ نرم که باز می‌شود و محو می‌شود
/// ۲) شمسه‌ای که می‌چرخد، بزرگ می‌شود و کم‌رنگ می‌شود
/// ۳) ۱۴ جرقهٔ طلایی که با گرانش پرت می‌شوند
class WinGlowPulse extends Component {
  WinGlowPulse({
    required this.center,
    required this.color,
    this.maxRadius = 70,
    this.sparkCount = 14,
  });

  final Vector2 center;
  final Color color;
  final double maxRadius;
  final int sparkCount;

  double _t = 0;
  static const double _duration = 0.95;
  final math.Random _rnd = math.Random();
  late final List<_Spark> _sparks = List<_Spark>.generate(sparkCount, (i) {
    final a = (i / sparkCount) * math.pi * 2 + _rnd.nextDouble() * 0.35;
    final v = maxRadius * (1.5 + _rnd.nextDouble() * 1.5);
    return _Spark(
      angle: a,
      speed: v,
      size: 1.4 + _rnd.nextDouble() * 2.4,
      spin: (_rnd.nextDouble() - 0.5) * 8,
    );
  });

  bool get isDone => _t >= _duration;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (isDone) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (isDone) return;
    final p = (_t / _duration).clamp(0.0, 1.0).toDouble();
    final o = center.toOffset();

    // ۱) موج نور
    final eased = 1 - math.pow(1 - p, 3).toDouble();
    final radius = maxRadius * (0.20 + 1.05 * eased);
    final alpha = (1 - p) * (1 - p);
    canvas.drawCircle(
      o,
      radius,
      Paint()
        ..shader = RadialGradient(
          stops: const [0.0, 0.55, 1.0],
          colors: [
            color.withOpacity(alpha * 0.55),
            color.withOpacity(alpha * 0.22),
            color.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: o, radius: radius)),
    );
    canvas.drawCircle(
      o,
      radius * 0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * (1 - p) + 0.4
        ..color = color.withOpacity(alpha * 0.85),
    );

    // ۲) شمسهٔ بازشونده
    canvas.drawPath(
      PersianMotifs.shamseh(
        center: o,
        radius: radius * 0.66,
        points: 12,
        innerRatio: 0.55,
        softness: 0.45,
        rotation: p * 1.2,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withOpacity(alpha * 0.70),
    );

    // ۳) جرقه‌ها (با گرانش ملایم)
    final sparkPaint = Paint();
    for (final s in _sparks) {
      final d = s.speed * p * (1.25 - 0.35 * p);
      final pos = Offset(
        o.dx + math.cos(s.angle) * d,
        o.dy + math.sin(s.angle) * d + 42 * p * p,
      );
      sparkPaint.color = Color.lerp(
        const Color(0xFFFFF3CE),
        color,
        p,
      )!
          .withOpacity((1 - p) * 0.95);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(s.spin * p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: s.size * (1 - p * 0.5),
            height: s.size * 2.4 * (1 - p * 0.5),
          ),
          Radius.circular(s.size),
        ),
        sparkPaint,
      );
      canvas.restore();
    }
  }
}

class _Spark {
  _Spark({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
  });

  final double angle;
  final double speed;
  final double size;
  final double spin;
}
