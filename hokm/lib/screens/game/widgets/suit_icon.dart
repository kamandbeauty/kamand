import 'package:flutter/material.dart';

import '../../../game/cards/card_renderer.dart';
import '../../../game/cards/suit_paths.dart';
import '../../../game_engine/models/suit.dart';

/// آیکن خال — از همان مسیرهای برداری کارت‌ها.
/// هم در HUD و هم در دیالوگ انتخاب حکم استفاده می‌شود.
class SuitIcon extends StatelessWidget {
  const SuitIcon({
    super.key,
    required this.suit,
    this.size = 22,
    this.color,
  });

  final Suit suit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SuitPainter(suit, color ?? CardRenderer.suitColor(suit)),
    );
  }
}

class _SuitPainter extends CustomPainter {
  _SuitPainter(this.suit, this.color);

  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = SuitPaths.inRect(suit, Offset.zero & size);
    canvas.drawPath(
      path,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SuitPainter old) =>
      old.suit != suit || old.color != color;
}
