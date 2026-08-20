import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, LinearGradient;

/// کتابخانهٔ نقش‌مایه‌های ایرانی — همه چیز برداری و مقیاس‌پذیر.
///
/// این فایل «زبان بصری» بازی است: شمسه، ترنج، اسلیمی، گره‌چینی و
/// برقِ ورق‌طلا. همهٔ اجزای گرافیکی بازی (میز، کارت، افکت‌ها) از همین
/// چند تابع تغذیه می‌شوند تا کل بازی یک هویت واحد داشته باشد.
abstract final class PersianMotifs {
  // ================================================================
  // شمسه — ستارهٔ خورشیدی چندپر با نوکِ نرم
  // ================================================================

  /// ستارهٔ شمسه با [points] پر.
  ///
  /// [innerRatio] نسبت شعاع دره به قله؛ [softness] گردیِ نوک‌ها
  /// (۰ = نوک تیزِ کلاسیک، ۱ = گلبرگی و نرم).
  static Path shamseh({
    required Offset center,
    required double radius,
    int points = 8,
    double innerRatio = 0.62,
    double softness = 0.45,
    double rotation = 0,
  }) {
    final path = Path();
    final step = math.pi / points;
    final inner = radius * innerRatio;

    for (var i = 0; i < points * 2; i++) {
      final a = rotation + i * step;
      final r = i.isEven ? radius : inner;
      final p = Offset(
        center.dx + math.cos(a) * r,
        center.dy + math.sin(a) * r,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        final prevA = rotation + (i - 1) * step;
        final prevR = i.isEven ? inner : radius;
        final midA = (a + prevA) / 2;
        final midR = lerpDouble(prevR, r, 0.5)! * (1 + softness * 0.28);
        path.quadraticBezierTo(
          center.dx + math.cos(midA) * midR,
          center.dy + math.sin(midA) * midR,
          p.dx,
          p.dy,
        );
      }
    }
    path.close();
    return path;
  }

  /// حلقهٔ نقطه‌چینِ دور شمسه (مرواریدنشان) — برای عمق دادن به مدالیون.
  static void pearlRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    int count = 24,
    double dotRadius = 2,
    double rotation = 0,
  }) {
    final paint = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      final a = rotation + i * (math.pi * 2 / count);
      canvas.drawCircle(
        Offset(center.dx + math.cos(a) * radius, center.dy + math.sin(a) * radius),
        dotRadius,
        paint,
      );
    }
  }

  // ================================================================
  // ترنج — بیضیِ نوک‌دارِ قالیِ ایرانی
  // ================================================================

  static Path toranj(Rect rect) {
    final c = rect.center;
    final hw = rect.width / 2;
    final hh = rect.height / 2;
    return Path()
      ..moveTo(c.dx, c.dy - hh)
      ..cubicTo(c.dx + hw * 0.62, c.dy - hh * 0.62, c.dx + hw, c.dy - hh * 0.24,
          c.dx + hw * 0.86, c.dy)
      ..cubicTo(c.dx + hw, c.dy + hh * 0.24, c.dx + hw * 0.62, c.dy + hh * 0.62,
          c.dx, c.dy + hh)
      ..cubicTo(c.dx - hw * 0.62, c.dy + hh * 0.62, c.dx - hw, c.dy + hh * 0.24,
          c.dx - hw * 0.86, c.dy)
      ..cubicTo(c.dx - hw, c.dy - hh * 0.24, c.dx - hw * 0.62, c.dy - hh * 0.62,
          c.dx, c.dy - hh)
      ..close();
  }

  // ================================================================
  // اسلیمی — شاخهٔ پیچانِ ختایی با برگ
  // ================================================================

  /// یک شاخهٔ اسلیمی که از [origin] به سمت [angle] می‌پیچد.
  static Path eslimiSpray({
    required Offset origin,
    required double length,
    double angle = 0,
    double curl = 1,
  }) {
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    final nx = -dy;
    final ny = dx;
    Offset at(double t, double side) => Offset(
          origin.dx + dx * length * t + nx * length * side,
          origin.dy + dy * length * t + ny * length * side,
        );

    final path = Path()..moveTo(origin.dx, origin.dy);
    path.cubicTo(
      at(0.35, 0.22 * curl).dx, at(0.35, 0.22 * curl).dy, //
      at(0.72, 0.30 * curl).dx, at(0.72, 0.30 * curl).dy,
      at(0.94, 0.06 * curl).dx, at(0.94, 0.06 * curl).dy,
    );
    // برگِ نوکِ شاخه
    path.cubicTo(
      at(1.06, -0.02 * curl).dx, at(1.06, -0.02 * curl).dy,
      at(0.96, -0.20 * curl).dx, at(0.96, -0.20 * curl).dy,
      at(0.74, -0.14 * curl).dx, at(0.74, -0.14 * curl).dy,
    );
    path.cubicTo(
      at(0.52, -0.08 * curl).dx, at(0.52, -0.08 * curl).dy,
      at(0.28, 0.02 * curl).dx, at(0.28, 0.02 * curl).dy,
      origin.dx, origin.dy,
    );
    path.close();
    return path;
  }

  /// چهار (یا n) شاخهٔ اسلیمیِ متقارن حول یک مرکز — «لچکِ» گوشه‌ها.
  static void eslimiRosette(
    Canvas canvas,
    Offset center,
    double length,
    Paint paint, {
    int arms = 6,
    double rotation = 0,
    double curl = 1,
  }) {
    for (var i = 0; i < arms; i++) {
      final a = rotation + i * (math.pi * 2 / arms);
      canvas.drawPath(
        eslimiSpray(origin: center, length: length, angle: a, curl: curl),
        paint,
      );
    }
  }

  // ================================================================
  // گره‌چینی — شبکهٔ هشت‌وستارهٔ کاشیِ ایرانی
  // ================================================================

  /// شبکهٔ گره: ستاره‌های هشت‌پر روی گرید، با خطوط رابط.
  ///
  /// ارزان است (فقط Path و خط) و برای پس‌زمینه/پشت‌کارت مناسب.
  static void girih(
    Canvas canvas,
    Rect rect,
    Paint stroke, {
    required double cell,
    double starRatio = 0.42,
    Paint? nodePaint,
  }) {
    canvas.save();
    canvas.clipRect(rect);
    for (double y = rect.top - cell; y < rect.bottom + cell; y += cell) {
      for (double x = rect.left - cell; x < rect.right + cell; x += cell) {
        final c = Offset(x, y);
        canvas.drawPath(
          shamseh(
            center: c,
            radius: cell * starRatio,
            points: 8,
            innerRatio: 0.52,
            softness: 0,
            rotation: math.pi / 8,
          ),
          stroke,
        );
        // خطوط رابطِ گره (مربعِ چرخیده بین ستاره‌ها)
        final d = cell / 2;
        final diamond = Path()
          ..moveTo(c.dx + d, c.dy)
          ..lineTo(c.dx + cell - d * 0.0, c.dy)
          ..close();
        canvas.drawPath(diamond, stroke);
        if (nodePaint != null) {
          canvas.drawCircle(Offset(c.dx + d, c.dy + d), cell * 0.055, nodePaint);
        }
      }
    }
    canvas.restore();
  }

  // ================================================================
  // ورق‌طلا — شیدرِ برقِ فلزی
  // ================================================================

  /// گرادیانِ طلاییِ متحرک؛ [phase] بین ۰ و ۱ برقِ عبوری را جابه‌جا می‌کند.
  static Shader goldShader(Rect rect, {double phase = 0.35}) {
    final p = phase.clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [
        0.0,
        (p - 0.16).clamp(0.02, 0.9),
        p.clamp(0.05, 0.95),
        (p + 0.16).clamp(0.1, 0.98),
        1.0,
      ],
      colors: const [
        Color(0xFF8A5E1C),
        Color(0xFFD9AE55),
        Color(0xFFFFF0BE),
        Color(0xFFD9AE55),
        Color(0xFF8A5E1C),
      ],
    ).createShader(rect);
  }

  /// شیدرِ فیروزه‌ای — برای لعابِ کاشی.
  static Shader turquoiseShader(Rect rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF5FD9CD), Color(0xFF17756F)],
      ).createShader(rect);
}
