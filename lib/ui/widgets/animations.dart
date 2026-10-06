/// انیمیشن‌های کوچکِ مشترک رابط کاربری.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../util/persian.dart';

/// ظاهر شدنِ نرم با بزرگ‌شدن (برای چیپ‌ها، دکمه‌ها و پیام‌ها).
class PopIn extends StatelessWidget {
  const PopIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.begin = 0.8,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final double begin;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration + delay,
      curve: delay == Duration.zero
          ? Curves.easeOutBack
          : Interval(
              delay.inMilliseconds / (duration + delay).inMilliseconds,
              1,
              curve: Curves.easeOutBack,
            ),
      builder: (BuildContext context, double t, Widget? c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: begin + (1 - begin) * t, child: c),
      ),
      child: child,
    );
  }
}

/// درخششِ ضربان‌دار برای نشان دادنِ نوبتِ بازیکن.
class PulseGlow extends StatefulWidget {
  const PulseGlow({
    super.key,
    required this.child,
    required this.active,
    this.color = const Color(0xFFE8C87A),
    this.radius = 16,
  });

  final Widget child;
  final bool active;
  final Color color;
  final double radius;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseGlow old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.color.withValues(alpha: 0.25 + 0.45 * _c.value),
              blurRadius: widget.radius * (0.7 + 0.9 * _c.value),
              spreadRadius: widget.radius * 0.08 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// عددی که با تغییر مقدار، نرم بالا/پایین می‌رود (ارقام فارسی).
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 650),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, Widget? _) =>
          Text(fa(v.round()), style: style),
    );
  }
}

/// ورودِ کارت به وسطِ میز از سمتِ بازیکن.
class FlyIn extends StatelessWidget {
  const FlyIn({
    super.key,
    required this.child,
    required this.from,
    required this.distance,
    this.tilt = 0,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final Offset from;
  final double distance;
  final double tilt;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? c) {
        final double inv = 1 - t;
        return Transform.translate(
          offset: from * distance * inv,
          child: Transform.rotate(
            angle: tilt * t + inv * 0.3 * (from.dx >= 0 ? 1 : -1),
            child: Transform.scale(
              scale: 0.82 + 0.18 * t,
              child: Opacity(opacity: math.min(1, t * 2), child: c),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
