import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart'
    show
        Alignment,
        LinearGradient,
        RadialGradient,
        TextPainter,
        TextSpan,
        TextStyle;

import '../../game_engine/models/playing_card.dart';
import '../../game_engine/models/rank.dart';
import '../../game_engine/models/suit.dart';
import '../../storage/settings_model.dart' show CardBackStyle;
import 'suit_paths.dart';

/// رندر رویه‌ای (procedural) کارت‌ها — بدون هیچ فایل تصویری.
///
/// همه چیز با Path و Gradient رسم می‌شود تا در هر تراکم صفحه تیز باشد:
/// * روی کارت: بدنهٔ گرادیانی، ایندکس گوشه، پیپ‌های استاندارد یا
///   طراحی اختصاصی فیگرها (J/Q/K) و آس.
/// * پشت کارت: سه طرح قابل انتخاب در تنظیمات.
abstract final class CardRenderer {
  static final Map<Suit, Path> _unitCache = {
    for (final s in Suit.values) s: SuitPaths.unitPath(s),
  };

  static const double cornerRadiusFactor = 0.085;

  static Color suitColor(Suit suit) => switch (suit) {
        Suit.hearts || Suit.diamonds => const Color(0xFFC62F3B),
        Suit.spades || Suit.clubs => const Color(0xFF22262B),
      };

  static double radius(double width) => width * cornerRadiusFactor;

  // ================================================================
  // روی کارت
  // ================================================================

  static void paintFront(
    Canvas canvas,
    Rect rect,
    PlayingCard card, {
    bool highlighted = false,
    double? foilPhase,
  }) {
    final w = rect.width;
    final r = radius(w);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // بدنه
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: highlighted
            ? const [Color(0xFFFFFEF8), Color(0xFFFFF3D6)]
            : const [Color(0xFFFEFEFC), Color(0xFFF5F1E8)],
      ).createShader(rect);
    canvas.drawRRect(rrect, bodyPaint);

    // قاب باریک داخلی
    final innerRect = rect.deflate(w * 0.035);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, Radius.circular(r * 0.7)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.008
        ..color = const Color(0x14000000),
    );

    final color = suitColor(card.suit);
    _paintCornerIndex(canvas, rect, card, color);

    if (card.rank == Rank.ace) {
      _paintAce(canvas, rect, card, color);
    } else if (card.rank.value >= Rank.jack.value) {
      _paintCourt(canvas, rect, card, color);
    } else {
      _paintPips(canvas, rect, card, color);
    }

    // برق ورق‌طلا برای کارت برندهٔ دست — نوار نورانیِ موربِ متحرک
    if (foilPhase != null) {
      final bandW = w * 0.55;
      final x = rect.left - bandW + (w + bandW * 2) * foilPhase;
      final c = rect.center;
      final band = Rect.fromLTWH(
          x, rect.top - rect.height * 0.4, bandW, rect.height * 1.8);
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.42);
      canvas.translate(-c.dx, -c.dy);
      canvas.drawRect(
        band,
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0x00F6DE8D),
              Color(0x4DF6DE8D),
              Color(0x00F6DE8D),
            ],
          ).createShader(band),
      );
      canvas.restore();
    }

    // برجستگی انتخاب: قاب طلایی
    if (highlighted) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035
          ..color = const Color(0xFFE5B94F),
      );
    }
  }

  static void _paintCornerIndex(
      Canvas canvas, Rect rect, PlayingCard card, Color color) {
    final w = rect.width;
    final tp = TextPainter(
      text: TextSpan(
        text: card.rank.symbol,
        style: TextStyle(
          fontFamily: 'VazirmatnFD',
          fontWeight: FontWeight.w700,
          fontSize: w * 0.20,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    void drawCorner(Canvas c) {
      final pad = w * 0.075;
      tp.paint(c, Offset(pad, pad * 0.8));
      final pipSize = w * 0.155;
      final pipTop = pad * 0.8 + tp.height + w * 0.015;
      final pipLeft = pad + (tp.width - pipSize) / 2;
      _drawPip(
        c,
        card.suit,
        Rect.fromLTWH(pipLeft, pipTop, pipSize, pipSize),
        color,
        inverted: false,
      );
    }

    // گوشهٔ بالا-چپ
    canvas.save();
    canvas.translate(rect.left, rect.top);
    drawCorner(canvas);
    canvas.restore();

    // گوشهٔ پایین-راست (چرخیده ۱۸۰ درجه)
    canvas.save();
    canvas.translate(rect.right, rect.bottom);
    canvas.rotate(3.14159265); // pi
    drawCorner(canvas);
    canvas.restore();
  }

  static void _drawPip(Canvas canvas, Suit suit, Rect rect, Color color,
      {required bool inverted}) {
    canvas.save();
    if (inverted) {
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(3.14159265);
      canvas.translate(-rect.center.dx, -rect.center.dy);
    }
    canvas.drawPath(_unitCache[suit]!
            .transform(_rectTransform(rect)), Paint()..color = color);
    canvas.restore();
  }

  static Float64List _rectTransform(Rect rect) => Float64List.fromList(<double>[
        rect.width, 0, 0, 0, //
        0, rect.height, 0, 0,
        0, 0, 1, 0,
        rect.left, rect.top, 0, 1,
      ]);

  // ---------- پیپ‌های عددی ----------

  static const List<List<Offset>> _pipLayouts = [
    // 2
    [Offset(0.5, 0.25), Offset(0.5, 0.75)],
    // 3
    [Offset(0.5, 0.25), Offset(0.5, 0.5), Offset(0.5, 0.75)],
    // 4
    [
      Offset(0.28, 0.25), Offset(0.72, 0.25),
      Offset(0.28, 0.75), Offset(0.72, 0.75),
    ],
    // 5
    [
      Offset(0.28, 0.25), Offset(0.72, 0.25), Offset(0.5, 0.5),
      Offset(0.28, 0.75), Offset(0.72, 0.75),
    ],
    // 6
    [
      Offset(0.28, 0.25), Offset(0.72, 0.25),
      Offset(0.28, 0.5), Offset(0.72, 0.5),
      Offset(0.28, 0.75), Offset(0.72, 0.75),
    ],
    // 7
    [
      Offset(0.28, 0.25), Offset(0.72, 0.25), Offset(0.5, 0.375),
      Offset(0.28, 0.5), Offset(0.72, 0.5),
      Offset(0.28, 0.75), Offset(0.72, 0.75),
    ],
    // 8
    [
      Offset(0.28, 0.25), Offset(0.72, 0.25), Offset(0.5, 0.375),
      Offset(0.28, 0.5), Offset(0.72, 0.5), Offset(0.5, 0.625),
      Offset(0.28, 0.75), Offset(0.72, 0.75),
    ],
    // 9
    [
      Offset(0.28, 0.2), Offset(0.72, 0.2),
      Offset(0.28, 0.4), Offset(0.72, 0.4), Offset(0.5, 0.5),
      Offset(0.28, 0.6), Offset(0.72, 0.6),
      Offset(0.28, 0.8), Offset(0.72, 0.8),
    ],
    // 10
    [
      Offset(0.28, 0.18), Offset(0.72, 0.18), Offset(0.5, 0.29),
      Offset(0.28, 0.40), Offset(0.72, 0.40),
      Offset(0.28, 0.60), Offset(0.72, 0.60), Offset(0.5, 0.71),
      Offset(0.28, 0.82), Offset(0.72, 0.82),
    ],
  ];

  static void _paintPips(
      Canvas canvas, Rect rect, PlayingCard card, Color color) {
    final layout = _pipLayouts[card.rank.value - 2];
    final w = rect.width;
    final inner = Rect.fromLTWH(
      rect.left + w * 0.16,
      rect.top + rect.height * 0.16,
      w * 0.68,
      rect.height * 0.68,
    );
    final pipSize = w * (card.rank.value >= 9 ? 0.155 : 0.175);
    for (final pos in layout) {
      final cx = inner.left + pos.dx * inner.width;
      final cy = inner.top + pos.dy * inner.height;
      _drawPip(
        canvas,
        card.suit,
        Rect.fromCenter(
            center: Offset(cx, cy), width: pipSize, height: pipSize),
        color,
        inverted: pos.dy > 0.5,
      );
    }
  }

  // ---------- آس ----------

  static void _paintAce(
      Canvas canvas, Rect rect, PlayingCard card, Color color) {
    final w = rect.width;
    final center = rect.center;
    // هالهٔ ملایم پشت پیپ بزرگ
    canvas.drawCircle(
      center,
      w * 0.30,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.10), color.withOpacity(0.0)],
        ).createShader(
            Rect.fromCircle(center: center, radius: w * 0.30)),
    );
    _drawPip(
      canvas,
      card.suit,
      Rect.fromCenter(center: center, width: w * 0.42, height: w * 0.42),
      color,
      inverted: false,
    );
    // حلقهٔ تزئینی
    canvas.drawCircle(
      center,
      w * 0.335,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.010
        ..color = color.withOpacity(0.35),
    );
  }

  // ---------- فیگرها (J / Q / K) ----------

  static void _paintCourt(
      Canvas canvas, Rect rect, PlayingCard card, Color color) {
    final w = rect.width;
    final center = rect.center;
    final badgeR = w * 0.30;

    // نشان مدور مرکزی
    final badgeRect = Rect.fromCircle(center: center, radius: badgeR);
    canvas.drawCircle(
      center,
      badgeR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.55),
          colors: [color.withOpacity(0.16), color.withOpacity(0.05)],
        ).createShader(badgeRect),
    );
    canvas.drawCircle(
      center,
      badgeR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = color.withOpacity(0.5),
    );
    canvas.drawCircle(
      center,
      badgeR * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.007
        ..color = color.withOpacity(0.28),
    );

    // پیپ بزرگ در مرکز نشان
    _drawPip(
      canvas,
      card.suit,
      Rect.fromCenter(
          center: center.translate(0, w * 0.085),
          width: w * 0.24,
          height: w * 0.24),
      color,
      inverted: false,
    );

    // تاج برای شاه / تاج زنانهٔ ساده برای بی‌بی / سرباز برای سرباز
    _paintCourtCrown(canvas, center.translate(0, -w * 0.155), w * 0.20, card.rank, color);

    // حرف رتبه
    final tp = TextPainter(
      text: TextSpan(
        text: card.rank.symbol,
        style: TextStyle(
          fontFamily: 'VazirmatnFD',
          fontWeight: FontWeight.w700,
          fontSize: w * 0.30,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center.translate(-tp.width / 2, -w * 0.06 - tp.height / 2 + w * 0.02));
  }

  static void _paintCourtCrown(Canvas canvas, Offset center, double size,
      Rank rank, Color color) {
    final p = Path();
    final halfW = size * 0.55;
    final baseY = center.dy + size * 0.28;
    final topY = center.dy - size * 0.30;
    p.moveTo(center.dx - halfW, baseY);
    if (rank == Rank.king) {
      // تاج سه‌پر
      p.lineTo(center.dx - halfW * 0.82, topY + size * 0.12);
      p.lineTo(center.dx - halfW * 0.30, center.dy);
      p.lineTo(center.dx, topY);
      p.lineTo(center.dx + halfW * 0.30, center.dy);
      p.lineTo(center.dx + halfW * 0.82, topY + size * 0.12);
    } else if (rank == Rank.queen) {
      // تاج قوسی زنانه
      p.lineTo(center.dx - halfW * 0.7, center.dy - size * 0.05);
      p.cubicTo(
          center.dx - halfW * 0.5, topY, center.dx + halfW * 0.5, topY,
          center.dx + halfW * 0.7, center.dy - size * 0.05);
    } else {
      // سرباز: نیزه/کلاه ساده
      p.lineTo(center.dx, topY);
      p.lineTo(center.dx + halfW, baseY);
    }
    p.lineTo(center.dx + halfW, baseY);
    p.close();
    canvas.drawPath(p, Paint()..color = color.withOpacity(0.85));
  }

  // ================================================================
  // پشت کارت
  // ================================================================

  static void paintBack(
    Canvas canvas,
    Rect rect,
    CardBackStyle style, {
    double? shimmer,
  }) {
    final w = rect.width;
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(radius(w)));

    canvas.save();
    canvas.clipRRect(rrect);

    // پایه
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: switch (style) {
          CardBackStyle.classic => const [Color(0xFF33509E), Color(0xFF21356E)],
          CardBackStyle.persianTile =>
            const [Color(0xFF7A1F2B), Color(0xFF521219)],
          CardBackStyle.diagonal =>
            const [Color(0xFF1F4438), Color(0xFF122B22)],
        },
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final ink = Paint()
      ..color = (switch (style) {
        CardBackStyle.classic => const Color(0xFF9DB4F0),
        CardBackStyle.persianTile => const Color(0xFFE8C87E),
        CardBackStyle.diagonal => const Color(0xFF7FD4B2),
      })
          .withOpacity(0.30);

    switch (style) {
      case CardBackStyle.classic:
        _backLattice(canvas, rect, ink, diamondScale: 1.4);
      case CardBackStyle.persianTile:
        _backPersianTile(canvas, rect, ink);
      case CardBackStyle.diagonal:
        _backDiagonal(canvas, rect, ink);
    }

    // برقِ عبوریِ آرامِ پشت کارت (چرخهٔ ~۴ ثانیه، داخل کلیپ بماند)
    if (shimmer != null) {
      final cycle = (shimmer % 4.2) / 4.2;
      final bandW = w * 0.40;
      final x = rect.left - bandW + (w + bandW * 2) * cycle;
      final c = rect.center;
      final band = Rect.fromLTWH(
          x, rect.top - rect.height * 0.4, bandW, rect.height * 1.8);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(0.30);
      canvas.translate(-c.dx, -c.dy);
      canvas.drawRect(
        band,
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0x00FFFFFF),
              Color(0x17FFFFFF),
              Color(0x00FFFFFF),
            ],
          ).createShader(band),
      );
      canvas.restore();
    }

    canvas.restore();

    // قاب داخلی روشن
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect.deflate(w * 0.045), Radius.circular(radius(w) * 0.75)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.020
        ..color = const Color(0x66FFFFFF),
    );
  }

  static void _backLattice(Canvas canvas, Rect rect, Paint ink,
      {double diamondScale = 1.0}) {
    final step = rect.width * 0.16 * diamondScale;
    ink.style = PaintingStyle.stroke;
    ink.strokeWidth = rect.width * 0.008;
    for (double y = rect.top - rect.height;
        y < rect.bottom + rect.height;
        y += step) {
      canvas.drawLine(Offset(rect.left - rect.width, y),
          Offset(rect.right + rect.width, y + rect.width), ink);
      canvas.drawLine(Offset(rect.left - rect.width, y),
          Offset(rect.right + rect.width, y - rect.width), ink);
    }
  }

  static void _backPersianTile(Canvas canvas, Rect rect, Paint ink) {
    // موتیف کاشی: شبکهٔ مربع‌های دوچرخ با نقطهٔ مرکزی
    final s = rect.width * 0.185;
    ink.style = PaintingStyle.stroke;
    ink.strokeWidth = rect.width * 0.008;
    final dot = Paint()
      ..color = ink.color.withOpacity(0.45);
    for (double y = rect.top - s; y < rect.bottom + s; y += s * 1.45) {
      for (double x = rect.left - s; x < rect.right + s; x += s * 1.45) {
        final r = Rect.fromCenter(
            center: Offset(x, y), width: s, height: s);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(3.14159265 / 4);
        canvas.drawRect(Rect.fromCenter(
            center: Offset.zero, width: r.width, height: r.height), ink);
        canvas.restore();
        canvas.drawCircle(Offset(x, y), s * 0.13, dot);
      }
    }
  }

  static void _backDiagonal(Canvas canvas, Rect rect, Paint ink) {
    final step = rect.width * 0.13;
    ink.style = PaintingStyle.stroke;
    for (double y = rect.top - rect.height;
        y < rect.bottom + rect.height;
        y += step) {
      ink.strokeWidth = rect.width * 0.006;
      canvas.drawLine(Offset(rect.left - rect.width, y),
          Offset(rect.right + rect.width, y + rect.width * 0.6), ink);
      ink.strokeWidth = rect.width * 0.014;
      canvas.drawLine(Offset(rect.left - rect.width, y + step * 0.5),
          Offset(rect.right + rect.width, y + step * 0.5 + rect.width * 0.6),
          ink);
    }
  }
}
