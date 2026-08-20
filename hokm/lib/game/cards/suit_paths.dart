import 'dart:typed_data';
import 'dart:ui';

import '../../game_engine/models/suit.dart';

/// مسیرهای برداری چهار خال — طراحی اختصاصی، مقیاس‌پذیر در هر اندازه.
///
/// هر مسیر در جعبهٔ واحد (0..1) تعریف و هنگام رسم اسکیل می‌شود؛
/// پس کارت‌ها در هر DPI تیز باقی می‌مانند (بدون فایل تصویری).
abstract final class SuitPaths {
  /// مسیر نرمالِ خال در جعبهٔ 0..1.
  static Path unitPath(Suit suit) {
    return switch (suit) {
      Suit.hearts => _heart(),
      Suit.spades => _spade(),
      Suit.diamonds => _diamond(),
      Suit.clubs => _club(),
    };
  }

  /// مسیر خال دقیقاً داخل یک Rect (اسکیل + انتقال).
  static Path inRect(Suit suit, Rect rect) {
    final m = Float64List.fromList(<double>[
      rect.width, 0, 0, 0, //
      0, rect.height, 0, 0,
      0, 0, 1, 0,
      rect.left, rect.top, 0, 1,
    ]);
    return unitPath(suit).transform(m);
  }

  static Path _heart() {
    final p = Path();
    p.moveTo(0.50, 0.92);
    p.cubicTo(0.42, 0.78, 0.06, 0.64, 0.06, 0.38);
    p.cubicTo(0.06, 0.21, 0.19, 0.09, 0.33, 0.09);
    p.cubicTo(0.41, 0.09, 0.47, 0.15, 0.50, 0.22);
    p.cubicTo(0.53, 0.15, 0.59, 0.09, 0.67, 0.09);
    p.cubicTo(0.81, 0.09, 0.94, 0.21, 0.94, 0.38);
    p.cubicTo(0.94, 0.64, 0.58, 0.78, 0.50, 0.92);
    p.close();
    return p;
  }

  static Path _spade() {
    final p = Path();
    p.moveTo(0.50, 0.05);
    p.cubicTo(0.45, 0.20, 0.06, 0.36, 0.06, 0.56);
    p.cubicTo(0.06, 0.71, 0.19, 0.81, 0.32, 0.81);
    p.cubicTo(0.40, 0.81, 0.46, 0.77, 0.485, 0.70);
    // ساقه
    p.cubicTo(0.47, 0.80, 0.43, 0.89, 0.36, 0.96);
    p.lineTo(0.64, 0.96);
    p.cubicTo(0.57, 0.89, 0.53, 0.80, 0.515, 0.70);
    p.cubicTo(0.54, 0.77, 0.60, 0.81, 0.68, 0.81);
    p.cubicTo(0.81, 0.81, 0.94, 0.71, 0.94, 0.56);
    p.cubicTo(0.94, 0.36, 0.55, 0.20, 0.50, 0.05);
    p.close();
    return p;
  }

  static Path _diamond() {
    final p = Path();
    p.moveTo(0.50, 0.04);
    p.lineTo(0.90, 0.50);
    p.lineTo(0.50, 0.96);
    p.lineTo(0.10, 0.50);
    p.close();
    return p;
  }

  static Path _club() {
    final p = Path();
    const r = 0.205;
    // سه لوب دایره‌ای
    p.addOval(Rect.fromCircle(center: const Offset(0.50, 0.30), radius: r));
    p.addOval(Rect.fromCircle(center: const Offset(0.27, 0.55), radius: r));
    p.addOval(Rect.fromCircle(center: const Offset(0.73, 0.55), radius: r));
    // ساقه
    p.moveTo(0.455, 0.62);
    p.cubicTo(0.445, 0.78, 0.42, 0.89, 0.35, 0.96);
    p.lineTo(0.65, 0.96);
    p.cubicTo(0.58, 0.89, 0.555, 0.78, 0.545, 0.62);
    p.close();
    return p;
  }
}
