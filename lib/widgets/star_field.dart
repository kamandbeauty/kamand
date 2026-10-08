import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/horoscope/deterministic_random.dart';
import '../core/theme/app_theme.dart';

/// Ambient animated sky background ("Premium Mystical Glass").
///
/// Layers (all painted by a single [CustomPainter] inside one
/// [RepaintBoundary] — zero blur, zero per-star widgets):
///  * two very soft nebula tints drifting slowly (radial-gradient
///    shaders at ~6–8% alpha — atmosphere, not decoration),
///  * twinkling stars (deterministic, precomputed once per size).
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
          nebulaA: Color(0x148B7CF6),
          nebulaB: Color(0x0F64D2FF),
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
    if (size.isEmpty) return const _Sky([], []);
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
    // Two quiet nebula tints in opposite corners — kept well away from the
    // screen center so text always sits on calm sky.
    final nebulae = [
      _Nebula(
        x: 0.16 + rng.nextInt(100) / 1000,
        y: 0.14 + rng.nextInt(100) / 1000,
        radius: 0.36 + rng.nextInt(120) / 1000,
        phase: rng.nextInt(360) * 1.0,
        tintA: true,
      ),
      _Nebula(
        x: 0.74 + rng.nextInt(100) / 1000,
        y: 0.68 + rng.nextInt(100) / 1000,
        radius: 0.34 + rng.nextInt(120) / 1000,
        phase: rng.nextInt(360) * 1.0,
        tintA: false,
      ),
    ];
    return _Sky(stars, nebulae);
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

class _Sky {
  const _Sky(this.stars, this.nebulae);

  final List<_Star> stars;
  final List<_Nebula> nebulae;
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
  }

  void _paintNebulae(Canvas canvas, Size size) {
    final minDim = math.min(size.width, size.height);
    for (final n in sky.nebulae) {
      final drift = animate
          ? math.sin(progress * math.pi + n.phase * math.pi / 180)
          : 0.0;
      final cx = (n.x + 0.02 * drift) * size.width;
      final cy = (n.y + 0.015 * drift * -1) * size.height;
      final radius = n.radius * minDim;
      final color = n.tintA ? palette.nebulaA : palette.nebulaB;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
      final shader = ui.Gradient.radial(
        rect.center,
        radius,
        [color, color.withValues(alpha: 0)],
      );
      canvas.drawCircle(rect.center, radius, Paint()..shader = shader);
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

  @override
  bool shouldRepaint(_AmbientSkyPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.animate != animate ||
      oldDelegate.sky.stars.length != sky.stars.length ||
      oldDelegate.palette != palette;
}
