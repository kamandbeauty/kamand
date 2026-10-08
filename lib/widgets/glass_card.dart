import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

// Design tokens for the ASTRAL COSMOS glass surface.

/// The signature "glass" card, generation 4 — ASTRAL COSMOS: a
/// translucent cosmic-indigo surface with a white sheen gradient
/// (brighter at the top), the system's subtle silver hairline, and a
/// soft accent-tinted glow beneath; gentle press animation. No blur
/// filters — GPU-cheap and battery friendly (product spec §29/§38).
class GlassCard extends StatefulWidget {
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

  /// Optional accent color tinting the frame/gradient/glow.
  final Color? accent;
  final VoidCallback? onTap;

  /// Slightly stronger surface for hero cards.
  final bool highlight;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glow = widget.accent ?? theme.colorScheme.primary;
    final radius = widget.radius;

    // ASTRAL COSMOS glass (v1.12.0): a translucent cosmic-indigo tint
    // with a white sheen gradient (brighter at the top) and the system's
    // subtle silver hairline — layered glass with visual hierarchy, the
    // accent surviving as a whisper of colored glow beneath the card.
    final (tintAlpha, sheenTop, sheenBottom) = isDark
        ? (widget.highlight ? 0.50 : 0.38, widget.highlight ? 0.16 : 0.10,
            widget.highlight ? 0.06 : 0.03)
        : (0.0, widget.highlight ? 0.94 : 0.86, widget.highlight ? 0.80 : 0.68);

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Padding(
        padding: widget.margin ?? EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(radius),
            onHighlightChanged: widget.onTap == null
                ? null
                : (v) => setState(() => _pressed = v),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                color: isDark
                    ? AstralTokens.surfaceGlass.withValues(alpha: tintAlpha)
                    : null,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: sheenTop),
                    Colors.white.withValues(alpha: sheenBottom),
                  ],
                ),
                border: Border.all(
                  color: isDark
                      ? AstralTokens.borderSubtle
                      : const Color(0x14273254),
                  width: 1,
                ),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: glow
                              .withValues(alpha: widget.highlight ? 0.16 : 0.08),
                          blurRadius: widget.highlight ? 30 : 18,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: const Color(0x1A1B1F4B).withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              // A transparent Material above the decoration lets
              // ListTiles / SwitchListTiles hosted in glass cards paint
              // their own background & ink splashes correctly.
              child: Material(
                type: MaterialType.transparency,
                child: widget.child,
              ),
            ),
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
