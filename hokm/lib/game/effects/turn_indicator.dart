import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart' show RadialGradient;

/// هالهٔ نرم دور جایگاه بازیکنی که نوبتش است.
///
/// پالس ملایم دارد؛ ظریف و حرفه‌ای، بدون افکت شلوغ.
class TurnIndicator extends PositionComponent {
  TurnIndicator({required this.glowColor});

  final Color glowColor;
  double _t = 0;
  bool _active = false;

  bool get active => _active;

  void showAt(Vector2 center, double radius) {
    position.setFrom(center);
    size.setAll(radius * 2);
    anchor = Anchor.center;
    _active = true;
    _t = 0;
  }

  void hide() => _active = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_active) _t += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!_active) return;
    // پالس تنفسی ملایم (α بین 0.35 و 0.6)
    final pulse = 0.47 + 0.13 * (1 + ((0.9 * _t) % 2 - 1).abs());
    final rect = Offset.zero & size.toSize();
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withOpacity(0.30 * pulse + 0.18),
          glowColor.withOpacity(0.0),
        ],
      ).createShader(rect);
    canvas.drawOval(rect.inflate(size.x * 0.18), glow);
  }
}
