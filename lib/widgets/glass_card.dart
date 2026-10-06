import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The signature "glass" card: translucent layered surface with a soft
/// gradient, hairline border and rounded corners. No blur filters —
/// GPU-cheap and battery friendly (product spec §29/§38).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = AppTheme.cardRadius,
    this.accent,
    this.onTap,
    this.highlight = false,
  });

  final Widget? child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  /// Optional accent color tinting the card border/gradient.
  final Color? accent;
  final VoidCallback? onTap;

  /// Slightly stronger surface for hero cards.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = highlight
        ? (isDark ? AppTheme.darkCardHigh : Colors.white)
        : (isDark ? AppTheme.darkCard : Colors.white);
    final border = accent?.withValues(alpha: 0.55) ??
        (isDark ? AppTheme.darkBorder : AppTheme.lightBorder);
    final glow = accent ?? theme.colorScheme.primary;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: base.withValues(alpha: isDark ? 0.92 : 0.96),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  glow.withValues(alpha: highlight ? 0.10 : 0.05),
                  base.withValues(alpha: 0.0),
                ],
              ),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: glow.withValues(alpha: highlight ? 0.16 : 0.08),
                        blurRadius: highlight ? 26 : 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0x141B1F4B).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Zodiac symbol glyph with the symbols fallback font baked in.
class ZodiacSymbol extends StatelessWidget {
  const ZodiacSymbol(this.symbol, {super.key, this.fontSize = 28, this.color});

  final String symbol;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppTheme.gold
            : AppTheme.violetDeep);
    return Text(
      symbol,
      style: TextStyle(
        fontSize: fontSize,
        color: effective,
        fontFamilyFallback: const ['NotoSansSymbols'],
        height: 1.15,
      ),
    );
  }
}

/// Circular, animated score ring with Persian percentage.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.size = 92,
    this.strokeWidth = 8,
    this.color,
    this.showLabel = true,
    this.label,
  });

  final int score;
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool showLabel;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ringColor = color ?? _colorForScore(score, theme);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score / 100),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _ScoreRingPainter(
            progress: value,
            color: ringColor,
            strokeWidth: strokeWidth,
            trackColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          child: Center(
            child: showLabel
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_fa(score)}٪',
                        style: TextStyle(
                          fontSize: size * 0.24,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                      if (label != null)
                        Text(
                          label!,
                          style: TextStyle(
                            fontSize: size * 0.11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                    ],
                  )
                : null,
          ),
        ),
      ),
    );
  }

  static Color _colorForScore(int score, ThemeData theme) {
    if (score >= 80) return const Color(0xFF4CD97B);
    if (score >= 60) return AppTheme.sky;
    if (score >= 45) return AppTheme.gold;
    return AppTheme.rose;
  }
}

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withValues(alpha: 0.65), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}

String _fa(int v) {
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return v.toString().split('').map((c) => fa[int.parse(c)]).join();
}
