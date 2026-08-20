import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart' show RadialGradient, SweepGradient;

import '../decor/persian_motifs.dart';

/// نشانگر نوبت — «شمسهٔ نوبت».
///
/// هالهٔ تنفسیِ نرم + یک حلقهٔ شمسه که آرام می‌چرخد + کمانِ نوریِ
/// چرخان که دورِ جایگاه می‌گردد. ظریف، اما بلافاصله چشم را می‌گیرد.
class TurnIndicator extends PositionComponent {
  TurnIndicator({required this.glowColor});

  final Color glowColor;
  double _t = 0;
  double _in = 0; // انیمیشن ورود/خروج (0..1)
  bool _active = false;

  bool get active => _active;

  void showAt(Vector2 center, double radius) {
    position.setFrom(center);
    size.setAll(radius * 2);
    anchor = Anchor.center;
    if (!_active) _in = 0;
    _active = true;
  }

  void hide() => _active = false;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final target = _active ? 1.0 : 0.0;
    _in += (target - _in) * (1 - math.exp(-dt * 9));
  }

  @override
  void render(Canvas canvas) {
    if (_in <= 0.01) return;
    final rect = Offset.zero & size.toSize();
    final c = rect.center;
    final r = size.x / 2;
    final pulse = 0.5 + 0.5 * math.sin(_t * 2.2);
    final k = _easeOutBack(_in);

    // ۱) هالهٔ تنفسی
    canvas.drawOval(
      rect.inflate(size.x * (0.16 + 0.03 * pulse)),
      Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withOpacity((0.16 + 0.16 * pulse) * _in),
            glowColor.withOpacity(0.0),
          ],
        ).createShader(rect.inflate(size.x * 0.2)),
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(k);
    canvas.translate(-c.dx, -c.dy);

    // ۲) حلقهٔ شمسهٔ چرخان
    canvas.drawPath(
      PersianMotifs.shamseh(
        center: c,
        radius: r * 0.98,
        points: 12,
        innerRatio: 0.86,
        softness: 0.3,
        rotation: _t * 0.5,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = glowColor.withOpacity(0.55 * _in),
    );

    // ۳) کمانِ نوریِ در حال گردش
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.90),
      _t * 1.9,
      math.pi * 0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.0
        ..shader = SweepGradient(
          startAngle: _t * 1.9,
          endAngle: _t * 1.9 + math.pi * 0.55,
          colors: [
            glowColor.withOpacity(0.0),
            glowColor.withOpacity(0.95 * _in),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // ۴) مرواریدهای نوبت
    PersianMotifs.pearlRing(
      canvas,
      c,
      r * 1.06,
      glowColor.withOpacity(0.30 * _in),
      count: 16,
      dotRadius: r * 0.030,
      rotation: -_t * 0.35,
    );

    canvas.restore();
  }
}

/// easeOutBack سبک (بدون وابستگی به flutter/animation در این فایل).
double _easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final x = t - 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}
