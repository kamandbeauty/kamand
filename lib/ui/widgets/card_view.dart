/// نمایش یک برگ پاسور (رو یا پشت).
library;

import 'package:flutter/material.dart';

import '../../model/card.dart';
import '../../model/enums.dart';
import '../theme.dart';
import 'suit_icon.dart';

/// اندازهٔ استاندارد کارت بر اساس عرض.
const double kCardAspect = 1.42;

class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    required this.width,
    this.selected = false,
    this.playable = false,
    this.dimmed = false,
    this.isTrump = false,
    this.onTap,
    this.elevation = 4,
  });

  final PlayingCard card;
  final double width;
  final bool selected;
  final bool playable;
  final bool dimmed;
  final bool isTrump;
  final VoidCallback? onTap;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final double h = width * kCardAspect;
    final Color color =
        card.isJoker ? (card.isRedJoker ? AppColors.cardRed : AppColors.cardBlack)
                     : (card.suit.isRed ? AppColors.cardRed : AppColors.cardBlack);

    final Widget face = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(width * 0.11),
        border: Border.all(
          color: selected
              ? AppColors.gold
              : (isTrump
                  ? AppColors.goldDeep.withValues(alpha: 0.85)
                  : Colors.black.withValues(alpha: 0.25)),
          width: selected ? 2.4 : (isTrump ? 1.6 : 0.8),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: elevation,
            offset: Offset(0, elevation * 0.4),
          ),
          if (playable)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.65),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: width * 0.05,
            right: width * 0.07,
            child: _Corner(card: card, color: color, width: width),
          ),
          Positioned(
            bottom: width * 0.05,
            left: width * 0.07,
            child: Transform.rotate(
              angle: 3.14159,
              child: _Corner(card: card, color: color, width: width),
            ),
          ),
          Center(
            child: card.isJoker
                ? _JokerCenter(width: width, color: color)
                : (card.rank >= 11
                    ? _FaceCenter(card: card, color: color, width: width)
                    : SuitIcon(
                        suit: card.suit,
                        size: width * 0.46,
                        color: color,
                      )),
          ),
        ],
      ),
    );

    final Widget content = dimmed
        ? Opacity(opacity: 0.45, child: face)
        : face;

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.card, required this.color, required this.width});

  final PlayingCard card;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          card.label,
          style: TextStyle(
            fontSize: width * 0.30,
            height: 1,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        SizedBox(height: width * 0.03),
        SuitIcon(
          suit: card.isJoker ? Suit.joker : card.suit,
          size: width * 0.19,
          color: color,
        ),
      ],
    );
  }
}

class _FaceCenter extends StatelessWidget {
  const _FaceCenter({
    required this.card,
    required this.color,
    required this.width,
  });

  final PlayingCard card;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width * 0.58,
      height: width * 0.58 * kCardAspect * 0.72,
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.75), width: 1.3),
        borderRadius: BorderRadius.circular(width * 0.07),
        color: color.withValues(alpha: 0.06),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            card.label,
            style: TextStyle(
              fontSize: width * 0.34,
              height: 1,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          SizedBox(height: width * 0.04),
          SuitIcon(suit: card.suit, size: width * 0.2, color: color),
        ],
      ),
    );
  }
}

class _JokerCenter extends StatelessWidget {
  const _JokerCenter({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SuitIcon(suit: Suit.joker, size: width * 0.42, color: color),
        SizedBox(height: width * 0.05),
        Text(
          'جوکر',
          style: TextStyle(
            fontSize: width * 0.16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// پشتِ کارت با طرح انتخابیِ کاربر.
class CardBackView extends StatelessWidget {
  const CardBackView({
    super.key,
    required this.width,
    required this.back,
    this.elevation = 3,
  });

  final double width;
  final CardBack back;
  final double elevation;

  static const Map<CardBack, List<Color>> _palette = <CardBack, List<Color>>{
    CardBack.crimson: <Color>[Color(0xFFA62329), Color(0xFF6E1014)],
    CardBack.navy: <Color>[Color(0xFF28568F), Color(0xFF10294F)],
    CardBack.emerald: <Color>[Color(0xFF1C7A58), Color(0xFF0C3B2A)],
    CardBack.midnight: <Color>[Color(0xFF353A4A), Color(0xFF14161D)],
    CardBack.gold: <Color>[Color(0xFFB5892A), Color(0xFF6B4E10)],
  };

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = _palette[back]!;
    return Container(
      width: width,
      height: width * kCardAspect,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.11),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: elevation,
            offset: Offset(0, elevation * 0.4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.09),
        child: CustomPaint(painter: _BackPainter(colors.first)),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  const _BackPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final RRect frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.1),
    );
    canvas.drawRRect(frame, p);
    const double step = 7;
    canvas.save();
    canvas.clipRRect(frame);
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        p..strokeWidth = 0.8,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BackPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
