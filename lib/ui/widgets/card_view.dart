/// نمایش حرفه‌ای یک برگ پاسور (رو و پشت) با چیدمان استانداردِ نقش‌ها.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../model/card.dart';
import '../../model/enums.dart';
import '../theme.dart';
import 'suit_icon.dart';

/// نسبت ارتفاع به عرضِ کارت (استاندارد پوکر ۲٫۵ × ۳٫۵ اینچ).
const double kCardAspect = 1.4;

/// رنگ‌های کاغذ و جوهرِ کارت.
class _Ink {
  const _Ink._();
  static const Color red = Color(0xFFC01B23);
  static const Color redDeep = Color(0xFF8E1218);
  static const Color black = Color(0xFF1A1714);
  static const Color blackDeep = Color(0xFF000000);
  static const Color paperTop = Color(0xFFFFFDF8);
  static const Color paperBottom = Color(0xFFF2E9D8);
  static const Color edge = Color(0xFFCBBD9E);
}

/// چیدمانِ استانداردِ نمادها روی کارت‌های عددی.
/// هر مختصات در بازهٔ ‎[-1, 1]‎ نسبت به مرکزِ ناحیهٔ میانی است.
const Map<int, List<Offset>> _pipLayout = <int, List<Offset>>{
  2: <Offset>[Offset(0, -1), Offset(0, 1)],
  3: <Offset>[Offset(0, -1), Offset(0, 0), Offset(0, 1)],
  4: <Offset>[
    Offset(-1, -1),
    Offset(1, -1),
    Offset(-1, 1),
    Offset(1, 1),
  ],
  5: <Offset>[
    Offset(-1, -1),
    Offset(1, -1),
    Offset(0, 0),
    Offset(-1, 1),
    Offset(1, 1),
  ],
  6: <Offset>[
    Offset(-1, -1),
    Offset(1, -1),
    Offset(-1, 0),
    Offset(1, 0),
    Offset(-1, 1),
    Offset(1, 1),
  ],
  7: <Offset>[
    Offset(-1, -1),
    Offset(1, -1),
    Offset(0, -0.5),
    Offset(-1, 0),
    Offset(1, 0),
    Offset(-1, 1),
    Offset(1, 1),
  ],
  8: <Offset>[
    Offset(-1, -1),
    Offset(1, -1),
    Offset(0, -0.5),
    Offset(-1, 0),
    Offset(1, 0),
    Offset(0, 0.5),
    Offset(-1, 1),
    Offset(1, 1),
  ],
  9: <Offset>[
    Offset(-1, -1),
    Offset(1, -1),
    Offset(-1, -0.33),
    Offset(1, -0.33),
    Offset(0, 0),
    Offset(-1, 0.33),
    Offset(1, 0.33),
    Offset(-1, 1),
    Offset(1, 1),
  ],
  10: <Offset>[
    Offset(-1, -1),
    Offset(1, -1),
    Offset(0, -0.66),
    Offset(-1, -0.33),
    Offset(1, -0.33),
    Offset(-1, 0.33),
    Offset(1, 0.33),
    Offset(0, 0.66),
    Offset(-1, 1),
    Offset(1, 1),
  ],
};

/// یک برگ پاسور.
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
    this.elevation = 5,
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
    final bool red = card.isJoker ? card.isRedJoker : card.suit.isRed;
    final Color color = red ? _Ink.red : _Ink.black;
    final Color colorDeep = red ? _Ink.redDeep : _Ink.blackDeep;
    final double radius = width * 0.1;

    final Widget face = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_Ink.paperTop, _Ink.paperBottom],
        ),
        border: Border.all(
          color: selected
              ? AppColors.gold
              : (isTrump
                  ? AppColors.goldDeep.withValues(alpha: 0.9)
                  : _Ink.edge),
          width: selected ? width * 0.045 : (isTrump ? width * 0.03 : 0.8),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: elevation,
            offset: Offset(0, elevation * 0.42),
          ),
          if (playable)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.75),
              blurRadius: width * 0.3,
              spreadRadius: width * 0.015,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 0.8),
        child: Stack(
          children: <Widget>[
            // بافتِ ملایمِ کاغذ
            Positioned.fill(
              child: CustomPaint(
                painter: _PaperPainter(color.withValues(alpha: 0.05)),
              ),
            ),
            // ناحیهٔ میانی
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  width * 0.23,
                  width * 0.1,
                  width * 0.23,
                  width * 0.1,
                ),
                child: _center(color, colorDeep),
              ),
            ),
            // گوشهٔ بالا-راست
            Positioned(
              top: width * 0.045,
              right: width * 0.055,
              child: _Corner(card: card, color: color, width: width),
            ),
            // گوشهٔ پایین-چپ (وارونه)
            Positioned(
              bottom: width * 0.045,
              left: width * 0.055,
              child: Transform.rotate(
                angle: math.pi,
                child: _Corner(card: card, color: color, width: width),
              ),
            ),
          ],
        ),
      ),
    );

    final Widget content = dimmed
        ? ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color(0x66101010),
              BlendMode.srcATop,
            ),
            child: face,
          )
        : face;

    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _center(Color color, Color colorDeep) {
    if (card.isJoker) {
      return _JokerCenter(width: width, color: color, colorDeep: colorDeep);
    }
    if (card.rank >= 11 && card.rank <= 13) {
      return _CourtCenter(
        card: card,
        color: color,
        colorDeep: colorDeep,
        width: width,
      );
    }
    if (card.rank == 14) {
      return _AceCenter(suit: card.suit, color: color, width: width);
    }
    return _PipField(suit: card.suit, rank: card.rank, width: width);
  }
}

/// گوشهٔ کارت: رتبه روی نماد خال.
class _Corner extends StatelessWidget {
  const _Corner({
    required this.card,
    required this.color,
    required this.width,
  });

  final PlayingCard card;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final bool wide = card.label.length > 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: width * (wide ? 0.27 : 0.2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: width * 0.3,
                height: 1,
                letterSpacing: -0.5,
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(height: width * 0.025),
        SuitIcon(
          suit: card.isJoker ? Suit.joker : card.suit,
          size: width * 0.17,
          color: color,
        ),
      ],
    );
  }
}

/// چیدمانِ نمادها روی کارت‌های ۲ تا ۱۰.
class _PipField extends StatelessWidget {
  const _PipField({
    required this.suit,
    required this.rank,
    required this.width,
  });

  final Suit suit;
  final int rank;
  final double width;

  @override
  Widget build(BuildContext context) {
    final List<Offset> spots = _pipLayout[rank] ?? const <Offset>[Offset(0, 0)];
    final double pip = width * 0.21;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double cx = box.maxWidth / 2;
        final double cy = box.maxHeight / 2;
        final double ax = (box.maxWidth - pip) / 2;
        final double ay = (box.maxHeight - pip) / 2;
        return Stack(
          children: <Widget>[
            for (final Offset o in spots)
              Positioned(
                left: cx + o.dx * ax - pip / 2,
                top: cy + o.dy * ay - pip / 2,
                child: Transform.rotate(
                  angle: o.dy > 0.05 ? math.pi : 0,
                  child: SuitIcon(suit: suit, size: pip),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// آس: نمادِ بزرگ با حلقهٔ تزئینی.
class _AceCenter extends StatelessWidget {
  const _AceCenter({
    required this.suit,
    required this.color,
    required this.width,
  });

  final Suit suit;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: width * 0.56,
        height: width * 0.56,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: Size.square(width * 0.56),
              painter: _RingPainter(color.withValues(alpha: 0.35)),
            ),
            SuitIcon(suit: suit, size: width * 0.38, color: color),
          ],
        ),
      ),
    );
  }
}

/// سرباز/بی‌بی/شاه: قابِ تزئینی با حرفِ بزرگ و نمادِ آینه‌ای.
class _CourtCenter extends StatelessWidget {
  const _CourtCenter({
    required this.card,
    required this.color,
    required this.colorDeep,
    required this.width,
  });

  final PlayingCard card;
  final Color color;
  final Color colorDeep;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 0.66,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.06),
            border: Border.all(
              color: color.withValues(alpha: 0.55),
              width: math.max(0.8, width * 0.015),
            ),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[
                color.withValues(alpha: 0.10),
                color.withValues(alpha: 0.02),
                color.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _CourtPainter(color.withValues(alpha: 0.3)),
                ),
              ),
              // نیمهٔ بالا
              Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.5,
                  child: _CourtHalf(
                    card: card,
                    color: color,
                    colorDeep: colorDeep,
                    width: width,
                  ),
                ),
              ),
              // نیمهٔ پایین (وارونه، مثل ورق واقعی)
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.5,
                  child: Transform.rotate(
                    angle: math.pi,
                    child: _CourtHalf(
                      card: card,
                      color: color,
                      colorDeep: colorDeep,
                      width: width,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourtHalf extends StatelessWidget {
  const _CourtHalf({
    required this.card,
    required this.color,
    required this.colorDeep,
    required this.width,
  });

  final PlayingCard card;
  final Color color;
  final Color colorDeep;
  final double width;

  IconData get _icon {
    switch (card.rank) {
      case 13:
        return Icons.workspace_premium_rounded;
      case 12:
        return Icons.spa_rounded;
      default:
        return Icons.shield_moon_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(width * 0.03),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(_icon, size: width * 0.2, color: colorDeep),
            SizedBox(height: width * 0.015),
            Text(
              card.label,
              style: TextStyle(
                fontSize: width * 0.3,
                height: 1,
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            SizedBox(height: width * 0.02),
            SuitIcon(suit: card.suit, size: width * 0.15, color: color),
          ],
        ),
      ),
    );
  }
}

/// جوکر.
class _JokerCenter extends StatelessWidget {
  const _JokerCenter({
    required this.width,
    required this.color,
    required this.colorDeep,
  });

  final double width;
  final Color color;
  final Color colorDeep;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.auto_awesome_rounded,
              size: width * 0.34,
              color: colorDeep,
            ),
            SizedBox(height: width * 0.04),
            Text(
              'جوکر',
              style: TextStyle(
                fontSize: width * 0.17,
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── نقاشی‌های کمکی ─────────────────────────────────────────────────────

class _PaperPainter extends CustomPainter {
  const _PaperPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    for (double y = 0; y < size.height; y += 4.5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) => old.color != color;
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, size.width * 0.022);
    canvas.drawCircle(c, r * 0.96, p);
    canvas.drawCircle(c, r * 0.82, p..strokeWidth = math.max(0.5, r * 0.02));
    // چهار نقطهٔ تزئینی
    final Paint dot = Paint()..color = color;
    for (int i = 0; i < 4; i++) {
      final double a = math.pi / 4 + i * math.pi / 2;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.89,
        math.max(0.8, r * 0.05),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}

class _CourtPainter extends CustomPainter {
  const _CourtPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    // خطِ مورّبِ میانی مثل ورق‌های واقعی
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      p,
    );
    final double inset = size.width * 0.08;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inset,
          inset,
          size.width - inset * 2,
          size.height - inset * 2,
        ),
        Radius.circular(size.width * 0.06),
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(_CourtPainter old) => old.color != color;
}

// ── پشتِ کارت ──────────────────────────────────────────────────────────

/// پشتِ کارت با طرحِ انتخابیِ کاربر.
class CardBackView extends StatelessWidget {
  const CardBackView({
    super.key,
    required this.width,
    this.back = CardBack.crimson,
    this.elevation = 4,
  });

  final double width;
  final CardBack back;
  final double elevation;

  static const Map<CardBack, List<Color>> _palette = <CardBack, List<Color>>{
    CardBack.crimson: <Color>[Color(0xFF8E1B22), Color(0xFF4E0D11)],
    CardBack.navy: <Color>[Color(0xFF1D3A66), Color(0xFF0C1B33)],
    CardBack.emerald: <Color>[Color(0xFF16684B), Color(0xFF07301F)],
    CardBack.midnight: <Color>[Color(0xFF2B2A3D), Color(0xFF12111C)],
    CardBack.gold: <Color>[Color(0xFF9A7224), Color(0xFF4A3410)],
  };

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = _palette[back] ?? _palette[CardBack.crimson]!;
    final double h = width * kCardAspect;
    final double radius = width * 0.1;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: _Ink.paperTop,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: elevation,
            offset: Offset(0, elevation * 0.4),
          ),
        ],
      ),
      padding: EdgeInsets.all(math.max(1.2, width * 0.035)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius * 0.75),
        child: CustomPaint(
          painter: _BackPainter(colors[0], colors[1]),
          size: Size(width, h),
        ),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  const _BackPainter(this.top, this.bottom);

  final Color top;
  final Color bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[top, bottom],
        ).createShader(rect),
    );

    // شبکهٔ لوزی
    final Paint line = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = math.max(0.5, size.width * 0.012)
      ..style = PaintingStyle.stroke;
    final double step = size.width / 4.5;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), line);
      canvas.drawLine(Offset(i, size.height), Offset(i + size.height, 0), line);
    }

    // قابِ طلایی
    final Paint frame = Paint()
      ..color = const Color(0xFFE8C87A).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, size.width * 0.022);
    final double inset = size.width * 0.09;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inset,
          inset,
          size.width - inset * 2,
          size.height - inset * 2,
        ),
        Radius.circular(size.width * 0.06),
      ),
      frame,
    );

    // مدالِ مرکزی
    final Offset c = size.center(Offset.zero);
    final double r = size.width * 0.2;
    canvas.drawCircle(
      c,
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFFE8C87A).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, size.width * 0.02),
    );
    final Path star = Path();
    for (int i = 0; i < 8; i++) {
      final double a = i * math.pi / 4;
      final double rr = i.isEven ? r * 0.62 : r * 0.3;
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()..color = const Color(0xFFE8C87A).withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_BackPainter old) => old.top != top || old.bottom != bottom;
}
