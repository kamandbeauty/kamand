/// انیمیشنِ پخشِ ورق در شروعِ هر راند.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../model/enums.dart';
import 'card_view.dart';

/// ورق‌ها از وسطِ زمین به سمتِ بازیکن‌ها «پخش» می‌شوند.
///
/// این فقط یک لایهٔ تزئینی است؛ موتورِ بازی کارتش را از قبل پخش کرده است.
class DealAnimation extends StatefulWidget {
  const DealAnimation({
    super.key,
    required this.seats,
    this.back = CardBack.crimson,
  });

  final int seats;
  final CardBack back;

  @override
  State<DealAnimation> createState() => _DealAnimationState();
}

class _DealAnimationState extends State<DealAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// مقصدِ هر صندلی به‌صورت نسبی (نسبت به وسطِ صفحه).
  List<Alignment> get _targets => widget.seats == 2
      ? const <Alignment>[Alignment(0, 1.02), Alignment(0, -0.92)]
      : const <Alignment>[
          Alignment(0, 1.02),
          Alignment(1.0, 0.02),
          Alignment(0, -0.92),
          Alignment(-1.0, 0.02),
        ];

  @override
  Widget build(BuildContext context) {
    final List<Alignment> targets = _targets;
    const int perSeat = 3;
    final int total = targets.length * perSeat + 1;

    return IgnorePointer(
      ignoring: false,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // تیرگیِ ملایمِ پس‌زمینه در حینِ پخش
              Opacity(
                opacity: (1 - _c.value).clamp(0.0, 1.0) * 0.35,
                child: const ColoredBox(color: Colors.black),
              ),
              for (int i = 0; i < total; i++) _card(i, total, targets),
            ],
          );
        },
      ),
    );
  }

  Widget _card(int i, int total, List<Alignment> targets) {
    // هر ورق با کمی تأخیر پرواز می‌کند.
    final double start = (i / total) * 0.72;
    final double t = ((_c.value - start) / 0.28).clamp(0.0, 1.0);
    const Curve curve = Curves.easeOutCubic;
    final double p = curve.transform(t);

    final bool isKitty = i == total - 1;
    final Alignment target = isKitty
        ? const Alignment(0, 0.05)
        : targets[i % targets.length];
    final Alignment pos = Alignment.lerp(
      const Alignment(0, -0.12),
      target,
      p,
    )!;

    // بعد از رسیدن، ورق محو می‌شود تا دستِ واقعی دیده شود.
    final double fade = t >= 1 ? 0.0 : (t > 0 ? 1.0 : 0.0);
    if (fade == 0) return const SizedBox.shrink();

    return Align(
      alignment: pos,
      child: Transform.rotate(
        angle: (1 - p) * math.pi * 0.6 + (i.isEven ? 0.06 : -0.06),
        child: Opacity(
          opacity: (1 - math.pow(p, 6)).toDouble().clamp(0.0, 1.0),
          child: CardBackView(width: 46, back: widget.back, elevation: 6),
        ),
      ),
    );
  }
}
