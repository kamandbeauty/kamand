import 'dart:ui';

import 'package:flame/components.dart';

/// تاجِ طلایی حاکم — بلافاصله پس از انتخاب حکم، بالای نامِ حاکم
/// می‌نشیند تا هم‌تیمی‌ها بدانند حکم با کیست.
class HakimCrown extends PositionComponent {
  HakimCrown({Color gold = const Color(0xFFD9A62E)})
      : _gold = gold {
    size.setValues(30, 20);
    anchor = Anchor.center;
  }

  final Color _gold;

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // تنهٔ تاج: سه نوک تیز با ته‌نوار — فرم کلاسیک تاج شاهی.
    final crown = Path()
      ..moveTo(3, h - 5.5)
      ..lineTo(1.5, h * 0.30)
      ..quadraticBezierTo(w * 0.16, h * 0.42, w * 0.26, h * 0.66)
      ..lineTo(w * 0.5, 1.5)
      ..lineTo(w * 0.74, h * 0.66)
      ..quadraticBezierTo(w * 0.84, h * 0.42, w - 1.5, h * 0.30)
      ..lineTo(w - 3, h - 5.5)
      ..close();

    final fill = Paint()
      ..color = _gold
      ..style = PaintingStyle.fill;
    canvas.drawPath(crown, fill);

    final rim = Paint()
      ..color = const Color(0xFF8A6420)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(crown, rim);

    // ته‌نوارِ تاج (نوار طلایی تیره‌تر با لبهٔ روشن).
    final bandRect = Rect.fromLTWH(2.5, h - 8.2, w - 5, 6.2);
    final band = Paint()..color = const Color(0xFFB8860B);
    canvas.drawRRect(
        RRect.fromRectAndRadius(bandRect, const Radius.circular(2.4)), band);
    final bandEdge = Paint()
      ..color = const Color(0xFFFFE9A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(
        RRect.fromRectAndRadius(bandRect, const Radius.circular(2.4)),
        bandEdge);

    // سه نگین روی نیم‌دایرهٔ تاج: زمرد، یاقوت سرخ، الماس.
    const gems = [Color(0xFF2EC4A6), Color(0xFFE63946), Color(0xCCFFFFFF)];
    final gemX = [w * 0.30, w * 0.50, w * 0.70];
    for (var i = 0; i < gems.length; i++) {
      final gemPaint = Paint()..color = gems[i];
      canvas.drawCircle(
          Offset(gemX[i], h * 0.475), i == 1 ? 1.9 : 1.6, gemPaint);
    }
  }
}
