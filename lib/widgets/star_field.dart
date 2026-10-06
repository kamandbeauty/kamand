import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/horoscope/deterministic_random.dart';

/// Subtle animated star-field background ("Premium Mystical Glass").
///
/// Performance & testability notes:
/// - Stars are precomputed once per size and painted in a single
///   RepaintBoundary (no per-star widgets).
/// - The shimmer is a one-shot 6s tween (not an infinite repeating
///   controller) so widget tests can settle and battery use stays minimal.
/// - Fully disabled when the user requests reduced motion.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final stars = _buildStars(size);
        return RepaintBoundary(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: enabled ? const Duration(seconds: 6) : Duration.zero,
            curve: Curves.easeInOut,
            builder: (context, t, _) => CustomPaint(
              painter: _StarFieldPainter(
                stars: stars,
                progress: t,
                starColor: isDark
                    ? const Color(0x66FFFFFF)
                    : const Color(0x334756D7),
                goldColor:
                    isDark ? const Color(0x99E8C77B) : const Color(0x66C9A24B),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  List<_Star> _buildStars(Size size) {
    if (size.isEmpty) return const [];
    final rng = DetRandom(0x51A17E);
    return List.generate(starCount, (i) {
      return _Star(
        x: rng.nextInt(1000) / 1000,
        y: rng.nextInt(1000) / 1000,
        radius: 0.6 + rng.nextInt(140) / 100,
        phase: rng.nextInt(360) * 1.0,
        speed: 0.4 + rng.nextInt(120) / 100,
        gold: rng.nextInt(100) > 82,
      );
    });
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

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter({
    required this.stars,
    required this.progress,
    required this.starColor,
    required this.goldColor,
  });

  final List<_Star> stars;
  final double progress;
  final Color starColor;
  final Color goldColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in stars) {
      final t = (progress * star.speed + star.phase / 360) % 1.0;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.cos(t * 2 * math.pi));
      paint.color = (star.gold ? goldColor : starColor)
          .withValues(alpha: (star.gold ? 0.7 : 0.55) * twinkle);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius * (0.7 + 0.3 * twinkle),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarFieldPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.stars.length != stars.length ||
      oldDelegate.starColor != starColor;
}
