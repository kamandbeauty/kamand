import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart' show RadialGradient;

import '../../game_engine/models/playing_card.dart';
import '../../storage/settings_model.dart' show CardBackStyle;
import '../animations/motion.dart';
import '../cards/card_renderer.dart';

/// کامپوننت یک کارت روی میز — رندر برداری + حرکت نرم + تعامل لمسی.
///
/// بازطراحی: سایهٔ سه‌لایه‌ای که با ارتفاعِ کارت زنده است، هالهٔ طلاییِ
/// کارتِ قابل‌بازی، دیمِ نرمِ کارت غیرمجاز، و برقِ عبوریِ ورق‌طلا روی
/// کارتِ برندهٔ دست.
class CardComponent extends PositionComponent with TapCallbacks, SmoothMotion {
  CardComponent({
    required this.card,
    required this.cardBackStyle,
    this.faceUp = false,
    this.onTapped,
  });

  PlayingCard card;
  CardBackStyle cardBackStyle;

  /// رو یا پشت.
  bool faceUp;

  /// قابلیت لمس (فقط در نوبت انسان و برای کارت‌های مجاز).
  bool interactive = false;

  /// کارت از نظر قوانین «مجاز» است (برای ظاهر — غیرمجازها کم‌رنگ‌تر).
  bool playable = true;

  /// کارتِ برندهٔ دست — برقِ طلایی می‌گیرد.
  bool winner = false;

  void Function(PlayingCard card)? onTapped;

  /// جای منطقی فعلی کارت (برای بازچینی هنگام resize).
  int slotIndex = 0;
  int slotCount = 1;

  // --- حالت‌های بصریِ نرم‌شونده ---
  double _dim = 0; // 0 = روشن، 1 = محو
  double _highlight = 0; // هالهٔ کارت قابل انتخاب
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    updateMotion(dt);

    final dimTarget = (!playable && faceUp) ? 1.0 : 0.0;
    final hlTarget = interactive ? 1.0 : 0.0;
    final k = 1 - math.exp(-dt * 10);
    _dim += (dimTarget - _dim) * k;
    _highlight += (hlTarget - _highlight) * k;
  }

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & size.toSize();
    final r = CardRenderer.radius(size.x);

    // هالهٔ طلاییِ کارتِ قابل انتخاب (نفس می‌کشد)
    if (_highlight > 0.02) {
      final pulse = 0.55 + 0.45 * math.sin(_t * 3.0);
      final glowRect = rect.inflate(size.x * 0.22);
      canvas.drawOval(
        glowRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFE8C46B)
                  .withOpacity(0.22 * _highlight * (0.6 + 0.4 * pulse)),
              const Color(0x00E8C46B),
            ],
          ).createShader(glowRect),
      );
    }

    // سایهٔ سه‌لایه — هرچه کارت بالاتر (scale بزرگ‌تر) سایه پخش‌تر
    final lift = (scale.y - 1).clamp(0.0, 0.6);
    final sh = 1 + lift * 2.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(size.x * 0.030 * sh, size.y * 0.070 * sh),
        Radius.circular(r),
      ),
      Paint()..color = Color.fromARGB((26 * sh).clamp(0, 90).toInt(), 0, 0, 0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(size.x * 0.016 * sh, size.y * 0.034 * sh),
        Radius.circular(r),
      ),
      Paint()..color = Color.fromARGB((38 * sh).clamp(0, 110).toInt(), 0, 0, 0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(size.x * 0.005, size.y * 0.010),
        Radius.circular(r),
      ),
      Paint()..color = const Color(0x22000000),
    );

    // بدنهٔ کارت
    if (faceUp) {
      CardRenderer.paintFront(
        canvas,
        rect,
        card,
        highlighted: _highlight > 0.5,
        foilPhase: winner ? (_t * 0.55) % 1.0 : null,
      );
    } else {
      CardRenderer.paintBack(canvas, rect, cardBackStyle, shimmer: _t);
    }

    // دیمِ کارت غیرمجاز
    if (_dim > 0.02) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(r)),
        Paint()
          ..color = Color.fromARGB((90 * _dim).toInt(), 10, 15, 22),
      );
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (interactive && onTapped != null) {
      onTapped!(card);
    }
    event.handled = interactive;
  }
}
