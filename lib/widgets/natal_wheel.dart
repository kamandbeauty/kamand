import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../domain/astrology/natal_chart.dart';

/// The natal-chart wheel — a circular map of the birth sky, drawn in the
/// language of the v1.9.0 design reference: a midnight-indigo field, a
/// warm-cream zodiac ring with degree ticks, antique-gold accents, and
/// the planets placed at their true longitudes (counterclockwise, with
/// the ascendant on the left when the birth time is known).
///
/// Everything is painted (no assets, no blur) so it stays crisp and
/// light on weak phones.
class NatalWheel extends StatelessWidget {
  const NatalWheel({
    super.key,
    required this.chart,
    this.size = 320,
  });

  final NatalChart chart;
  final double size;

  static const Map<String, String> _glyphs = {
    'moon': '☽',
    'mercury': '☿',
    'venus': '♀',
    'mars': '♂',
    'jupiter': '♃',
    'saturn': '♄',
    // The sun glyph (☉) is missing from the bundled symbol font, so the
    // painter draws a little rayed disc instead.
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NatalWheelPainter(
          chart: chart,
          cream: scheme.onSurface,
          gold: scheme.primary,
          card: scheme.surface,
          violet: AppTheme.violet,
          rose: AppTheme.rose,
          sky: AppTheme.sky,
        ),
      ),
    );
  }
}

class _NatalWheelPainter extends CustomPainter {
  _NatalWheelPainter({
    required this.chart,
    required this.cream,
    required this.gold,
    required this.card,
    required this.violet,
    required this.rose,
    required this.sky,
  });

  final NatalChart chart;
  final Color cream;
  final Color gold;
  final Color card;
  final Color violet;
  final Color rose;
  final Color sky;

  static const _deg2rad = math.pi / 180.0;

  /// Longitude of 0° Aries is placed at 9 o'clock; longitudes grow
  /// counterclockwise. With a known ascendant the wheel rotates so the
  /// rising sign sits at 9 o'clock (the classical convention).
  double get _rotation => chart.ascendant?.longitudeDegrees ?? 0;

  Offset _point(Offset c, double radius, double longitude) {
    final a = math.pi - (longitude - _rotation) * _deg2rad;
    return Offset(c.dx + radius * math.cos(a), c.dy - radius * math.sin(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 6;
    final rSignOut = r;
    final rSignIn = r * 0.78;
    final rPlanet = r * 0.60;
    final rAspect = r * 0.36;

    // ── Center glow (violet nebula over midnight) ────────────────────
    canvas.drawCircle(
      c,
      rSignIn,
      Paint()
        ..shader = RadialGradient(
          colors: [violet.withValues(alpha: 0.16), violet.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: rSignIn)),
    );

    // ── Zodiac ring: alternating segment fills ──────────────────────
    for (var i = 0; i < 12; i++) {
      // Canvas angles grow clockwise (y is down); our longitudes grow
      // counterclockwise, hence the negated start and positive sweep.
      final start = -(math.pi - (i * 30 - _rotation) * _deg2rad);
      final sweep = 30 * _deg2rad;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: (rSignOut + rSignIn) / 2),
        start,
        sweep,
        true,
        Paint()
          ..color = cream.withValues(alpha: i.isEven ? 0.05 : 0.10)
          ..style = PaintingStyle.fill,
      );
    }

    // ── Ring borders: cream outer + thin gold inner ─────────────────
    canvas.drawCircle(
      c,
      rSignOut,
      Paint()
        ..color = cream.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      c,
      rSignOut - 5,
      Paint()
        ..color = gold.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawCircle(
      c,
      rSignIn,
      Paint()
        ..color = cream.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Degree ticks (every 5°, long & gold every 30°) ──────────────
    for (var d = 0; d < 360; d += 5) {
      final major = d % 30 == 0;
      final len = major ? 9.0 : 4.0;
      final p1 = _point(c, rSignOut - 1, d.toDouble());
      final p2 = _point(c, rSignOut - 1 - len, d.toDouble());
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = major
              ? gold.withValues(alpha: 0.75)
              : cream.withValues(alpha: 0.30)
          ..strokeWidth = major ? 1.2 : 0.7,
      );
    }

    // ── Sign separator rays + glyphs ────────────────────────────────
    for (var i = 0; i <= 12; i++) {
      final lon = i * 30.0;
      canvas.drawLine(
        _point(c, rSignIn, lon),
        _point(c, rSignOut, lon),
        Paint()
          ..color = cream.withValues(alpha: 0.18)
          ..strokeWidth = 0.7,
      );
    }
    final symbols = _signSymbols();
    for (var i = 0; i < 12; i++) {
      final mid = i * 30.0 + 15;
      final p = _point(c, (rSignIn + rSignOut) / 2 - 3, mid);
      _text(canvas, symbols[i], p, cream, (rSignOut - rSignIn) * 0.62);
    }

    // ── House cusps (dotted) when the time is known ─────────────────
    if (chart.ascendant != null) {
      for (final house in chart.houses) {
        for (var t = 0.0; t < 1.0; t += 0.12) {
          final p1 = _point(c, rAspect + (rSignIn - rAspect) * t,
              house.cuspDegrees);
          final p2 = _point(
              c, rAspect + (rSignIn - rAspect) * (t + 0.06), house.cuspDegrees);
          canvas.drawLine(
            p1,
            p2,
            Paint()
              ..color = cream.withValues(alpha: 0.14)
              ..strokeWidth = 0.7,
          );
        }
      }
    }

    // ── Aspect lines between the planets ────────────────────────────
    final placed = _placedPlanets(c, rPlanet);
    for (final a in chart.aspects) {
      final pa = placed[a.bodyA];
      final pb = placed[a.bodyB];
      if (pa == null || pb == null) continue;
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..color = _aspectColor(a.kind).withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
    }

    // ── Planets: staggered badges along their band ──────────────────
    for (final pos in chart.planetPositions) {
      final p = placed[pos.body]!;
      final badge = size.shortestSide * 0.036;
      if (pos.body == 'sun') {
        _drawSun(canvas, p, badge * 0.9, gold);
      } else {
        canvas.drawCircle(
          p,
          badge,
          Paint()..color = card.withValues(alpha: 0.92),
        );
        canvas.drawCircle(
          p,
          badge,
          Paint()
            ..color = gold.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9,
        );
        _text(canvas, NatalWheel._glyphs[pos.body] ?? '?', p, cream,
            badge * 1.35);
      }
      if (pos.isRetrograde) {
        canvas.drawCircle(
          Offset(p.dx + badge * 0.95, p.dy + badge * 0.95),
          2.2,
          Paint()..color = rose.withValues(alpha: 0.9),
        );
      }
    }

    // ── Ascendant arrow (9 o'clock) & MC diamond ────────────────────
    final ascP1 = Offset(c.dx - rSignOut + 2, c.dy);
    final ascP2 = Offset(c.dx - rSignOut + 13, c.dy);
    canvas.drawLine(
      ascP1,
      ascP2,
      Paint()
        ..color = gold
        ..strokeWidth = 2,
    );
    final ascTip = Offset(ascP1.dx - 5, c.dy);
    final ascWing1 = Offset(ascP1.dx + 3, c.dy - 4);
    final ascWing2 = Offset(ascP1.dx + 3, c.dy + 4);
    canvas.drawPath(
      Path()
        ..moveTo(ascTip.dx, ascTip.dy)
        ..lineTo(ascWing1.dx, ascWing1.dy)
        ..lineTo(ascWing2.dx, ascWing2.dy)
        ..close(),
      Paint()..color = gold,
    );
    if (chart.ascendant != null) {
      final mc = _point(c, rSignOut - 10, chart.ascendant!.midheavenDegrees);
      canvas.drawCircle(mc, 2.6, Paint()..color = gold);
    }
  }

  /// Planet positions on the wheel, nudged outward when they cluster.
  Map<String, Offset> _placedPlanets(Offset c, double baseRadius) {
    final sorted = [...chart.planetPositions]
      ..sort((a, b) => a.longitudeDegrees.compareTo(b.longitudeDegrees));
    final out = <String, Offset>{};
    var level = 0;
    double? prevLon;
    for (final pos in sorted) {
      if (prevLon != null) {
        final gap = pos.longitudeDegrees - prevLon;
        if (gap < 16) {
          level = (level + 1) % 3;
        } else {
          level = 0;
        }
      }
      final radius = baseRadius + level * baseRadius * 0.22;
      out[pos.body] = _point(c, radius, pos.longitudeDegrees);
      prevLon = pos.longitudeDegrees;
    }
    return out;
  }

  List<String> _signSymbols() => const [
        '♈', '♉', '♊', '♋', '♌', '♍',
        '♎', '♏', '♐', '♑', '♒', '♓',
      ];

  Color _aspectColor(String kind) => switch (kind) {
        'trine' => const Color(0xFF4CD97B),
        'square' => rose,
        'opposition' => gold,
        'conjunction' => violet,
        _ => sky,
      };

  /// A small rayed sun (the ☉ glyph is missing from the bundled font).
  void _drawSun(Canvas canvas, Offset p, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      canvas.drawLine(
        Offset(p.dx + r * 0.55 * math.cos(a), p.dy + r * 0.55 * math.sin(a)),
        Offset(p.dx + r * math.cos(a), p.dy + r * math.sin(a)),
        paint,
      );
    }
    canvas.drawCircle(p, r * 0.38, Paint()..color = color);
  }

  void _text(Canvas canvas, String s, Offset center, Color color,
      double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: 'Vazirmatn',
          fontFamilyFallback: const ['NotoSansSymbols'],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _NatalWheelPainter old) =>
      old.chart != chart;
}
