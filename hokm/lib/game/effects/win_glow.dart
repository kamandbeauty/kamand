import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart' show RadialGradient;

/// پالس نورانی کوتاه برای بردن دور — یک موج نرم که باز می‌شود و محو می‌شود.
class WinGlowPulse extends Component {
  WinGlowPulse({required this.center, required this.color, this.maxRadius = 70});

  final Vector2 center;
  final Color color;
  final double maxRadius;

  double _t = 0;
  static const double _duration = 0.55;

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
    final p = _t / _duration;
    final eased = 1 - (1 - p) * (1 - p); // easeOutQuad
    final radius = maxRadius * (0.25 + 0.75 * eased);
    final alpha = (1 - p) * 0.75;
    canvas.drawCircle(
      center.toOffset(),
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(alpha), color.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: center.toOffset(), radius: radius)),
    );
    // حلقهٔ ظریف
    canvas.drawCircle(
      center.toOffset(),
      radius * 0.85,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withOpacity(alpha * 0.7),
    );
  }
}
