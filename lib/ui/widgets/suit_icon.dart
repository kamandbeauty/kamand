/// نمادهای خال به‌صورت برداری (مستقل از فونت دستگاه).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../model/card.dart';

class SuitIcon extends StatelessWidget {
  const SuitIcon({
    super.key,
    required this.suit,
    required this.size,
    this.color,
  });

  final Suit suit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SuitPainter(
          suit,
          color ??
              (suit.isRed ? const Color(0xFFC0252B) : const Color(0xFF16130F)),
        ),
      ),
    );
  }
}

class _SuitPainter extends CustomPainter {
  const _SuitPainter(this.suit, this.color);

  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    switch (suit) {
      case Suit.hearts:
        canvas.drawPath(_heart(w, h), paint);
      case Suit.diamonds:
        canvas.drawPath(_diamond(w, h), paint);
      case Suit.spades:
        canvas.drawPath(_spade(w, h), paint);
      case Suit.clubs:
        _club(canvas, paint, w, h);
      case Suit.joker:
        canvas.drawPath(_star(w, h), paint);
    }
  }

  static Path _heart(double w, double h) {
    final Path p = Path()..moveTo(w * 0.5, h * 0.95);
    p.cubicTo(w * -0.08, h * 0.56, w * 0.1, h * 0.02, w * 0.5, h * 0.3);
    p.cubicTo(w * 0.9, h * 0.02, w * 1.08, h * 0.56, w * 0.5, h * 0.95);
    p.close();
    return p;
  }

  static Path _diamond(double w, double h) {
    final Path p = Path()
      ..moveTo(w * 0.5, h * 0.03)
      ..lineTo(w * 0.93, h * 0.5)
      ..lineTo(w * 0.5, h * 0.97)
      ..lineTo(w * 0.07, h * 0.5)
      ..close();
    return p;
  }

  static Path _spade(double w, double h) {
    final Path p = Path()..moveTo(w * 0.5, h * 0.04);
    p.cubicTo(w * 0.5, h * 0.3, w * 0.02, h * 0.4, w * 0.02, h * 0.63);
    p.cubicTo(w * 0.02, h * 0.82, w * 0.32, h * 0.87, w * 0.46, h * 0.7);
    p.cubicTo(w * 0.46, h * 0.84, w * 0.4, h * 0.92, w * 0.3, h * 0.97);
    p.lineTo(w * 0.7, h * 0.97);
    p.cubicTo(w * 0.6, h * 0.92, w * 0.54, h * 0.84, w * 0.54, h * 0.7);
    p.cubicTo(w * 0.68, h * 0.87, w * 0.98, h * 0.82, w * 0.98, h * 0.63);
    p.cubicTo(w * 0.98, h * 0.4, w * 0.5, h * 0.3, w * 0.5, h * 0.04);
    p.close();
    return p;
  }

  static void _club(Canvas canvas, Paint paint, double w, double h) {
    final double r = w * 0.225;
    canvas.drawCircle(Offset(w * 0.5, h * 0.27), r, paint);
    canvas.drawCircle(Offset(w * 0.25, h * 0.62), r, paint);
    canvas.drawCircle(Offset(w * 0.75, h * 0.62), r, paint);
    final Path stem = Path()
      ..moveTo(w * 0.44, h * 0.55)
      ..cubicTo(w * 0.46, h * 0.8, w * 0.38, h * 0.9, w * 0.3, h * 0.97)
      ..lineTo(w * 0.7, h * 0.97)
      ..cubicTo(w * 0.62, h * 0.9, w * 0.54, h * 0.8, w * 0.56, h * 0.55)
      ..close();
    canvas.drawPath(stem, paint);
  }

  static Path _star(double w, double h) {
    final Path p = Path();
    const int points = 5;
    final double cx = w / 2;
    final double cy = h / 2;
    final double outer = w * 0.5;
    final double inner = w * 0.22;
    for (int i = 0; i < points * 2; i++) {
      final double r = i.isEven ? outer : inner;
      final double a = -math.pi / 2 + i * math.pi / points;
      final double x = cx + r * math.cos(a);
      final double y = cy + r * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant _SuitPainter old) =>
      old.suit != suit || old.color != color;
}
