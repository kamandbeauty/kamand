import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart'
    show Alignment, LinearGradient, RadialGradient;

import '../decor/persian_motifs.dart';
import '../table/table_theme.dart';

/// پس‌زمینهٔ میز — هویت بصری ایرانی:
/// فرش با گره‌چینیِ ظریف، شمسهٔ مرکزی با حلقهٔ مروارید، لچک‌های اسلیمی
/// در گوشه‌ها، باند لعابِ فیروزهٔ دور قاب و شست‌وشوی نورِ متحرک.
///
/// برای عملکرد بهینه فقط Path و گرادیان استفاده می‌شود (بدون Blur).
class TableBackground extends PositionComponent {
  TableBackground({required this.palette});

  /// پالت فعال — از تنظیمات به‌صورت زنده قابل تعویض است.
  TablePalette palette;

  double _t = 0; // ساعت شست‌وشوی نور

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final full = Offset.zero & size.toSize();

    // ۱) بدنهٔ بیرونی میز (چوب تیره)
    canvas.drawRect(full, Paint()..color = palette.rimOuter);
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 1.15,
          colors: [palette.rimInner, palette.rimOuter],
        ).createShader(full),
    );

    // چارچوب فرش
    final feltInset = w * 0.045;
    final feltRect = Rect.fromLTWH(
      feltInset,
      h * 0.032,
      w - feltInset * 2,
      h - h * 0.032 - feltInset,
    );
    final feltRRect =
        RRect.fromRectAndRadius(feltRect, Radius.circular(w * 0.075));

    // ۲) باند لعاب فیروزه دور قاب (کاشی‌کاری حاشیه — مرز چوب↔فرش)
    final glazeRect = feltRect.inflate(w * 0.022);
    final glazeRRect = RRect.fromRectAndRadius(
        glazeRect, Radius.circular(w * 0.095));
    canvas.drawRRect(
      glazeRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.026
        ..color = palette.glaze.withOpacity(0.75),
    );
    // خط نازک طلایی میان لعاب
    canvas.drawRRect(
      glazeRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.006
        ..color = palette.rimHighlight.withOpacity(0.8),
    );
    // ترنج‌های لعابی در بالا و پایینِ باند
    for (final dy in [glazeRect.top, glazeRect.bottom]) {
      canvas.drawPath(
        PersianMotifs.toranj(Rect.fromCenter(
          center: Offset(feltRect.center.dx, dy),
          width: w * 0.14,
          height: w * 0.036,
        )),
        Paint()..color = palette.glaze.withOpacity(0.9),
      );
    }

    // ۳) فرش مرکزی با گرادیان شعاعی (نور از بالای مرکز)
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

    // ۴) گره‌چینیِ ظریف فرش — ستاره‌های هشت‌پر روی گرید
    PersianMotifs.girih(
      canvas,
      feltRect.deflate(w * 0.02),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = palette.patternLines,
      cell: w * 0.27,
      starRatio: 0.40,
    );

    final center = feltRect.center;

    // ۵) شمسهٔ مرکزی + حلقهٔ مروارید (آرام می‌چرخد)
    canvas.drawPath(
      PersianMotifs.shamseh(
        center: center,
        radius: w * 0.155,
        points: 12,
        innerRatio: 0.60,
        softness: 0.52,
        rotation: _t * 0.045,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = palette.medallion,
    );
    canvas.drawPath(
      PersianMotifs.shamseh(
        center: center,
        radius: w * 0.155,
        points: 12,
        innerRatio: 0.60,
        softness: 0.52,
        rotation: _t * 0.045,
      ),
      Paint()..color = palette.medallion.withOpacity(0.10),
    );
    PersianMotifs.pearlRing(
      canvas,
      center,
      w * 0.205,
      palette.medallion.withOpacity(0.55),
      count: 28,
      dotRadius: w * 0.0055,
      rotation: -_t * 0.03,
    );

    // ۶) لچک‌های اسلیمی در چهار گوشهٔ فرش (گل‌ریز متقارن)
    final eslimiPaint = Paint()..color = palette.medallion.withOpacity(0.42);
    final cornerPadX = feltRect.width * 0.315;
    final cornerPadY = feltRect.height * 0.295;
    final corners = [
      center.translate(-cornerPadX, -cornerPadY),
      center.translate(cornerPadX, -cornerPadY),
      center.translate(-cornerPadX, cornerPadY),
      center.translate(cornerPadX, cornerPadY),
    ];
    for (var i = 0; i < corners.length; i++) {
      PersianMotifs.eslimiRosette(
        canvas,
        corners[i],
        w * 0.052,
        eslimiPaint,
        arms: 4,
        rotation: i * math.pi / 4 + _t * 0.02,
      );
    }

    // ۷) شست‌وشوی نورِ متحرک روی فرش (چرخهٔ ۷ ثانیه)
    final wash = (_t % 7.0) / 7.0;
    final bandW = feltRect.width * 0.55;
    final washX =
        feltRect.left - bandW + (feltRect.width + bandW * 2) * wash;
    canvas.save();
    canvas.clipRRect(feltRRect);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.42);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRect(
      Rect.fromLTWH(washX, feltRect.top - feltRect.height * 0.4, bandW,
          feltRect.height * 1.8),
      Paint()
        ..shader = LinearGradient(
          colors: [
            palette.lightWash.withOpacity(0.0),
            palette.lightWash,
            palette.lightWash.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(washX, 0, bandW, h)),
    );
    canvas.restore();
    // توجه: canvas.save را بالا دادیم؛ کلیپ با restore پایانی آزاد می‌شود.

    // ۸) قاب داخلی فرش (دوخط ظریف)
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

    // ۹) برق لبهٔ بیرونی فرش (جدارهٔ چوب↔فرش)
    canvas.drawRRect(
      feltRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = palette.rimHighlight.withOpacity(0.5),
    );

    // ۱۰) سایهٔ داخلی ملایم دور فرش (عمق)
    canvas.drawRRect(
      feltRRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 1.25,
          stops: const [0.80, 1.0],
          colors: [Color(0x00000000), Color(0x38000000)],
        ).createShader(feltRect),
    );

    // ۱۱) وینیت گوشه‌ها
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.35,
          stops: const [0.72, 1.0],
          colors: [Color(0x00000000), Color(0x4D000000)],
        ).createShader(full),
    );
  }
}
