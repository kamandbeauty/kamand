import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve, Curves;

import 'package:flame/components.dart';

/// یک سگمنت حرکت: مقصد (اختیاری) + مدت + منحنی + ارتفاع قوس.
///
/// [arc] باعث می‌شود کارت در مسیر «بلند شود» (پارابولِ بالا) —
/// همان حس طبیعیِ برداشتن و گذاشتن کارت در دنیای واقعی.
class MotionSegment {
  const MotionSegment({
    this.to,
    this.angleTo,
    this.scaleTo,
    required this.duration,
    this.curve = Curves.easeInOutCubic,
    this.arc = 0,
  });

  final Vector2? to;
  final double? angleTo;
  final double? scaleTo;
  final Duration duration;

  /// منحنی زمانی — غیرخطی برای حس طبیعی.
  final Curve curve;

  /// ارتفاع قوس حرکت (پیکسل) — مثبت یعنی بالا رفتن در میانهٔ مسیر.
  final double arc;
}

class _ActiveSegment {
  _ActiveSegment(
    this.segment, {
    required this.fromPosition,
    required this.fromAngle,
    required this.fromScale,
  });

  final MotionSegment segment;
  final Vector2 fromPosition;
  final double fromAngle;
  final double fromScale;
  double elapsedMs = 0;
}

/// میکسین حرکت نرم برای PositionComponentها.
///
/// پیاده‌سازی اختصاصی (به‌جای اتکا صرف به Effectهای آمادهٔ Flame) تا:
/// * قوسِ حرکت (بلند شدن در مسیر) دقیقاً در کنترل ما باشد؛
/// * چند سگمنت پشت‌سرهم در یک صف اجرا شوند؛
/// * هر فراخوان یک Future برگرداند تا ریتم انیمیشن‌ها زنجیره‌پذیر باشد
///   (مثلاً: بردار → ببر → بچرخان → بگذار).
mixin SmoothMotion on PositionComponent {
  final List<MotionSegment> _queue = <MotionSegment>[];
  final List<Completer<void>> _waiters = <Completer<void>>[];
  _ActiveSegment? _active;

  /// ضریب زمانی انیمیشن (از تنظیمات) — بزرگ‌تر = کندتر.
  double motionSpeedFactor = 1.0;

  bool get isMoving => _active != null || _queue.isNotEmpty;

  /// اجرای صف سگمنت‌ها؛ Future وقتی کامل می‌شود که صف کاملاً تخلیه شده باشد.
  Future<void> animateMotion(List<MotionSegment> segments) {
    if (segments.isEmpty) return Future<void>.value();
    final completer = Completer<void>();
    _queue.addAll(segments);
    _waiters.add(completer);
    return completer.future;
  }

  /// لغو حرکت و (اختیاراً) پرش به حالت پایانی سگمنت فعال.
  void cancelMotion({bool jumpToEnd = true}) {
    if (jumpToEnd && _active != null) _applySegmentEnd(_active!);
    _queue.clear();
    _active = null;
    _drain();
  }

  void _drain() {
    for (final w in _waiters) {
      if (!w.isCompleted) w.complete();
    }
    _waiters.clear();
  }

  void updateMotion(double dt) {
    if (_active == null) {
      if (_queue.isEmpty) return;
      final next = _queue.removeAt(0);
      _active = _ActiveSegment(
        next,
        fromPosition: position.clone(),
        fromAngle: angle,
        fromScale: scale.x,
      );
    }

    final active = _active!;
    active.elapsedMs += dt * 1000 / math.max(motionSpeedFactor, 0.01);
    final durationMs = math.max(active.segment.duration.inMilliseconds, 1);
    final rawT = (active.elapsedMs / durationMs).clamp(0.0, 1.0).toDouble();
    final t = active.segment.curve.transform(rawT);

    // موقعیت با قوس پارابولیک (بلند شدن در میانهٔ مسیر)
    final from = active.fromPosition;
    final to = active.segment.to ?? from;
    final x = from.x + (to.x - from.x) * t;
    final y = from.y +
        (to.y - from.y) * t -
        active.segment.arc * 4 * t * (1 - t);
    position.setValues(x, y);

    final angleTo = active.segment.angleTo;
    if (angleTo != null) {
      angle = active.fromAngle + (angleTo - active.fromAngle) * t;
    }
    final scaleTo = active.segment.scaleTo;
    if (scaleTo != null) {
      final s = active.fromScale + (scaleTo - active.fromScale) * t;
      scale.setAll(s);
    }

    if (rawT >= 1.0) {
      _applySegmentEnd(active);
      _active = null;
      if (_queue.isEmpty) _drain();
    }
  }

  void _applySegmentEnd(_ActiveSegment active) {
    final to = active.segment.to;
    if (to != null) position.setFrom(to);
    final a = active.segment.angleTo;
    if (a != null) angle = a;
    final s = active.segment.scaleTo;
    if (s != null) scale.setAll(s);
  }
}
