import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/horoscope/deterministic_random.dart';
import '../core/theme/app_theme.dart';

/// Ambient animated sky background ("Premium Mystical Glass").
///
/// Layers (all painted by a single [CustomPainter] inside one
/// [RepaintBoundary] — zero blur, zero per-star widgets):
///  * two soft nebula blobs drifting slowly (radial-gradient shaders),
///  * twinkling stars (deterministic, precomputed once per size),
///  * one shooting star crossing near the end of the sweep.
///
/// Performance & testability notes:
/// - The whole animation is a one-shot 10s tween (not an infinite repeating
///   controller) so widget tests settle and battery use stays minimal.
/// - Fully static when the user requests reduced motion ([enabled] false).
/// - Colors come from the active theme skin via the [SkyPalette] extension,
///   so each «تمِ آسمان» has its own atmosphere.
class StarField extends StatelessWidget {
  const StarField({
    super.key,
    this.starCount = 42,
    this.child,
    this.enabled = true,
  });

  final int starCount;
  final Widget? child;

  /// Set false to skip animation (reduced-motion / battery friendly).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<SkyPalette>() ??
        const SkyPalette(
          star: Color(0x66FFFFFF),
          starGold: Color(0x99E8C77B),
          nebulaA: Color(0x2E8B7CF6),
          nebulaB: Color(0x1F64D2FF),
          meteor: Color(0xCCE8C77B),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final sky = _buildSky(size);
        return RepaintBoundary(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: enabled ? const Duration(seconds: 10) : Duration.zero,
            curve: Curves.easeInOut,
            builder: (context, t, _) => CustomPaint(
              painter: _AmbientSkyPainter(
                sky: sky,
                progress: enabled ? t : 1,
                animate: enabled,
                palette: palette,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  _Sky _buildSky(Size size) {
    if (size.isEmpty) return const _Sky([], [], null);
    final rng = DetRandom(0x51A17E);
    final stars = List.generate(starCount, (i) {
      return _Star(
        x: rng.nextInt(1000) / 1000,
        y: rng.nextInt(1000) / 1000,
        radius: 0.6 + rng.nextInt(140) / 100,
        phase: rng.nextInt(360) * 1.0,
        speed: 0.4 + rng.nextInt(120) / 100,
        gold: rng.nextInt(100) > 82,
      );
    });
    final nebulae = List.generate(3, (i) {
      return _Nebula(
        x: 0.18 + 0.3 * i + rng.nextInt(120) / 1000,
        y: 0.2 + rng.nextInt(500) / 1000,
        radius: 0.42 + rng.nextInt(200) / 1000,
        phase: rng.nextInt(360) * 1.0,
        tintA: i.isEven,
      );
    });
    final meteor = _Meteor(
      x0: 0.62 + rng.nextInt(200) / 1000,
      y0: 0.04 + rng.nextInt(120) / 1000,
      dx: -(0.28 + rng.nextInt(100) / 1000),
      dy: 0.22 + rng.nextInt(100) / 1000,
    );
    return _Sky(stars, nebulae, meteor);
  }
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.speed,
    required this.gold,
  });

  final double x; // 0..1
  final double y; // 0..1
  final double radius;
  final double phase; // degrees
  final double speed;
  final bool gold;
}

class _Nebula {
  const _Nebula({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.tintA,
  });

  final double x; // 0..1 (center, before drift)
  final double y; // 0..1
  final double radius; // fraction of min(w,h)
  final double phase; // degrees
  final bool tintA;
}

class _Meteor {
  const _Meteor({required this.x0, required this.y0, required this.dx, required this.dy});

  final double x0, y0; // start point (0..1)
  final double dx, dy; // travel vector (fractions)
}

class _Sky {
  const _Sky(this.stars, this.nebulae, this.meteor);

  final List<_Star> stars;
  final List<_Nebula> nebulae;
  final _Meteor? meteor;
}

class _AmbientSkyPainter extends CustomPainter {
  _AmbientSkyPainter({
    required this.sky,
    required this.progress,
    required this.animate,
    required this.palette,
  });

  final _Sky sky;
  final double progress;
  final bool animate;
  final SkyPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintNebulae(canvas, size);
    _paintStars(canvas, size);
    if (animate) _paintMeteor(canvas, size);
  }

  void _paintNebulae(Canvas canvas, Size size) {
    final minDim = math.min(size.width, size.height);
    for (final n in sky.nebulae) {
      final drift = animate
          ? math.sin(progress * math.pi * 2 * 0.5 + n.phase * math.pi / 180)
          : 0.0;
      final cx = (n.x + 0.035 * drift) * size.width;
      final cy = (n.y + 0.025 * drift * -1) * size.height;
      final radius = n.radius * minDim;
      final color = n.tintA ? palette.nebulaA : palette.nebulaB;
      final shader = _radial(
        Offset(cx - radius, cy - radius) & Size(radius * 2, radius * 2),
        color,
      );
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()..shader = shader,
      );
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in sky.stars) {
      final t = (progress * star.speed + star.phase / 360) % 1.0;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.cos(t * 2 * math.pi));
      paint.color = (star.gold ? palette.starGold : palette.star)
          .withValues(alpha: (star.gold ? 0.7 : 0.55) * twinkle);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius * (0.7 + 0.3 * twinkle),
        paint,
      );
    }
  }

  /// One shooting star between t = 0.62 and 0.78 of the sweep.
  void _paintMeteor(Canvas canvas, Size size) {
    const t0 = 0.62, t1 = 0.78;
    if (progress < t0 || progress > t1) return;
    final m = sky.meteor;
    if (m == null) return;
    final p = (progress - t0) / (t1 - t0);
    final ease = Curves.easeOutCubic.transform(p);
    final hx = (m.x0 + m.dx * ease) * size.width;
    final hy = (m.y0 + m.dy * ease) * size.height;
    final fade = math.sin(p * math.pi); // in and out
    final tailLen = 90.0 * (0.5 + 0.5 * ease);

    final tail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = _radial(
        Rect.fromCircle(center: Offset(hx, hy), radius: tailLen),
        palette.meteor.withValues(alpha: 0.85 * fade),
      );
    final dir = Offset(m.dx, m.dy) / math.sqrt(m.dx * m.dx + m.dy * m.dy);
    canvas.drawLine(
      Offset(hx, hy),
      Offset(hx - dir.dx * tailLen, hy - dir.dy * tailLen),
      tail,
    );
    canvas.drawCircle(
      Offset(hx, hy),
      1.8 + 1.2 * fade,
      Paint()..color = palette.meteor.withValues(alpha: 0.9 * fade),
    );
  }

  /// Radial gradient shader fading from [color] to transparent.
  static ui.Gradient _radial(Rect rect, Color color) => ui.Gradient.radial(
        rect.center,
        rect.shortestSide / 2,
        [color, color.withValues(alpha: 0)],
      );

  @override
  bool shouldRepaint(_AmbientSkyPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.animate != animate ||
      oldDelegate.sky.stars.length != sky.stars.length ||
      oldDelegate.palette != palette;
}
