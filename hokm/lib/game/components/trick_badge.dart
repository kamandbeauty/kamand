import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show Alignment, RadialGradient, TextPainter, TextSpan, TextStyle;

import '../../core/persian_utils.dart';

/// نشان شمارندهٔ دست‌های بردهٔ هر بازیکن — سکهٔ طلاییِ کوچکِ کنار پشته
/// که با هر برد، عددش (به رقم فارسی) زیاد می‌شود و می‌تپد.
class TrickBadge extends PositionComponent {
  TrickBadge({required this.accent});

  final Color accent;

  /// تعداد دست‌های بردهٔ این بازیکن در این دور.
  int count = 0;

  double _t = 0;
  double _pulse = 0;

  /// شمارنده را به‌روز می‌کند و یک تپشِ کوتاه پخش می‌کند.
  void bump(int newCount) {
    count = newCount;
    _pulse = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _pulse = math.max(0.0, _pulse - dt * 2.4);
  }

  @override
  void render(Canvas canvas) {
    if (count <= 0) return;
    final r = size.x / 2;
    final center = Offset(r, r);
    final pop = 1 + 0.22 * _pulse;
    final shimmer = 0.5 + 0.5 * math.sin(_t * 2.4);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pop);
    canvas.translate(-center.dx, -center.dy);

    // سایهٔ نرم
    canvas.drawCircle(
      center.translate(0, 1.4),
      r,
      Paint()..color = const Color(0x59000000),
    );
    // بدنهٔ طلایی
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          colors: const [Color(0xFFFFF0BE), Color(0xFFD9AE55)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    // هالهٔ ظریف هنگام تپش
    if (_pulse > 0.02) {
      canvas.drawCircle(
        center,
        r * (1 + 0.35 * _pulse),
        Paint()
          ..color = const Color(0xFFFFF0BE).withOpacity(0.30 * _pulse),
      );
    }
    // حاشیهٔ زر
    canvas.drawCircle(
      center,
      r - 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = Color.lerp(
            const Color(0xFF8A5E1C), const Color(0xFFB98A2F), shimmer)!,
    );

    // عدد فارسی
    final tp = TextPainter(
      text: TextSpan(
        text: toPersianDigits(count),
        style: const TextStyle(
          fontFamily: 'VazirmatnFD',
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF3A2A08),
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2 - 0.6));
    canvas.restore();
  }
}
