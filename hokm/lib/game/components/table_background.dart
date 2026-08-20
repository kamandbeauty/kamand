import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../table/table_theme.dart';

/// پس‌زمینهٔ میز — رسم یک‌بارهٔ لایه‌های محو/فرش/حاشیه.
///
/// برای عملکرد بهینه، نقاشی سنگین فقط در [render] با Path کم‌هزینه
/// انجام می‌شود (بدون Blur پرتعداد؛ سایه‌ها با گرادیان).
class TableBackground extends PositionComponent {
  TableBackground({required this.palette});

  final TablePalette palette;

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final full = Offset.zero & size.toSize();

    // ۱) بدنهٔ بیرونی میز (چوب تیره)
    canvas.drawRect(full, Paint()..color = palette.rimOuter);
    final rimGrad = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.15),
        radius: 1.15,
        colors: [palette.rimInner, palette.rimOuter],
      ).createShader(full);
    canvas.drawRect(full, rimGrad);

    // ۲) فرش مرکزی با گرادیان شعاعی (نور از بالای مرکز)
    final feltInset = w * 0.045;
    final feltRect = Rect.fromLTWH(
      feltInset,
      h * 0.032,
      w - feltInset * 2,
      h - h * 0.032 - feltInset,
    );
    final feltRRect =
        RRect.fromRectAndRadius(feltRect, Radius.circular(w * 0.075));

    final feltPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.25),
        radius: 1.25,
        stops: const [0.0, 0.62, 1.0],
        colors: [
          palette.feltCenter,
          Color.lerp(palette.feltCenter, palette.feltEdge, 0.55)!,
          palette.feltEdge,
        ],
      ).createShader(feltRect);
    canvas.drawRRect(feltRRect, feltPaint);

    // ۳) نقش‌مایهٔ ظریف فرش: دو حلقهٔ هم‌مرکز + مربع چرخیده
    final decor = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = palette.patternLines;
    final center = feltRect.center;
    canvas.drawCircle(center, w * 0.30, decor);
    canvas.drawCircle(center, w * 0.225, decor);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset.zero, width: w * 0.42, height: w * 0.42),
      decor,
    );
    canvas.restore();

    // ۴) قاب داخلی فرش (دوخط ظریف)
    canvas.drawRRect(
      feltRRect.deflate(w * 0.016),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = palette.accent.withOpacity(0.35),
    );
    canvas.drawRRect(
      feltRRect.deflate(w * 0.032),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = palette.accent.withOpacity(0.22),
    );

    // ۵) برق لبهٔ بیرونی فرش (جداره‌ی چوب↔فرش)
    canvas.drawRRect(
      feltRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = palette.rimHighlight.withOpacity(0.5),
    );

    // ۶) سایهٔ داخلی ملایم دور فرش (عمق)
    final innerShadow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.25),
        radius: 1.25,
        stops: const [0.80, 1.0],
        colors: [const Color(0x00000000), const Color(0x38000000)],
      ).createShader(feltRect);
    canvas.drawRRect(feltRRect, innerShadow);

    // ۷) وینیت گوشه‌ها
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.35,
        stops: const [0.72, 1.0],
        colors: [const Color(0x00000000), const Color(0x4D000000)],
      ).createShader(full);
    canvas.drawRect(full, vignette);
  }
}
