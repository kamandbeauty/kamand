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

  /// ورق‌های عددی (۲ تا ۱۰) که نمادِ خال روی آن‌ها چیده می‌شود.
  bool get _pips => !card.isJoker && card.rank >= 2 && card.rank <= 10;

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
            // ناحیهٔ میانی (برای نقش‌ها و آس بزرگ‌تر از ورق‌های عددی)
            Positioned.fill(
              child: Padding(
                padding: _pips
                    ? EdgeInsets.symmetric(
                        horizontal: width * 0.25,
                        vertical: width * 0.17,
                      )
                    : EdgeInsets.symmetric(
                        horizontal: width * 0.02,
                        vertical: width * 0.028,
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

    final Widget content = dimmed ? Opacity(opacity: 0.58, child: face) : face;

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
      return _CourtCenter(card: card, color: color, width: width);
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
          width: width * (wide ? 0.25 : 0.18),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: width * 0.27,
                height: 1,
                letterSpacing: -0.5,
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(height: width * 0.025),
        SuitIcon(
          suit: card.isJoker ? Suit.joker : card.suit,
          size: width * 0.15,
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
    final double pip = width * 0.17;
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
      child: SuitIcon(suit: suit, size: width * 0.88, color: color),
    );
  }
}

/// نامِ فایلِ نگارهٔ نقش برای [rank] (۱۱ تا ۱۳).
String courtAsset(int rank, bool red) {
  final String who = switch (rank) {
    11 => 'jack',
    12 => 'queen',
    _ => 'king',
  };
  return 'assets/cards/court_$who.png';
}

/// سرباز/بی‌بی/شاه: نگارهٔ تزئینی داخلِ قابِ طلایی.
class _CourtCenter extends StatelessWidget {
  const _CourtCenter({
    required this.card,
    required this.color,
    required this.width,
  });

  final PlayingCard card;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final Widget art = Image.asset(
      courtAsset(card.rank, card.suit.isRed),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) =>
          _CourtFallback(card: card, color: color, width: width),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(width * 0.03),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // نگارهٔ دوسر: بالا ایستاده، پایین وارونه (مثل ورقِ واقعی)
          Column(
            children: <Widget>[
              Expanded(child: ClipRect(child: art)),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: ClipRect(child: art),
                ),
              ),
            ],
          ),
          Center(
            child: Container(
              height: math.max(0.5, width * 0.004),
              color: color.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

/// اگر طرح در دسترس نبود: حرفِ بزرگ با نمادِ خال.
class _CourtFallback extends StatelessWidget {
  const _CourtFallback({
    required this.card,
    required this.color,
    required this.width,
  });

  final PlayingCard card;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SuitIcon(suit: card.suit, size: width * 0.15, color: color),
          SizedBox(height: width * 0.02),
          Text(
            card.label,
            style: TextStyle(
              fontSize: width * 0.40,
              height: 1,
              fontFamily: 'Vazirmatn',
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
              color: color,
            ),
          ),
          SizedBox(height: width * 0.02),
          Transform.rotate(
            angle: math.pi,
            child: SuitIcon(suit: card.suit, size: width * 0.15, color: color),
          ),
        ],
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
      child: AspectRatio(
        aspectRatio: 0.66,
        child: Image.asset(
          'assets/cards/court_joker.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SuitIcon(suit: Suit.joker, size: width * 0.42, color: color),
                SizedBox(height: width * 0.05),
                Text(
                  'جوکر',
                  style: TextStyle(
                    fontSize: width * 0.17,
                    fontFamily: 'Vazirmatn',
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                    color: colorDeep.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
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
