import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';

import '../../game_engine/models/playing_card.dart';
import '../../storage/settings_model.dart' show CardBackStyle;
import '../animations/motion.dart';
import '../cards/card_renderer.dart';

/// کامپوننت یک کارت روی میز — رندر برداری + حرکت نرم + تعامل لمسی.
///
/// * رندر سایهٔ نرم لایه‌ای + روی/پشت کارت از [CardRenderer].
/// * حالت برجسته (انتخاب) با قاب طلایی.
/// * [onTapped] فقط وقتی صدا زده می‌شود که کارت تعاملی باشد.
class CardComponent extends PositionComponent
    with TapCallbacks, SmoothMotion {
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

  void Function(PlayingCard card)? onTapped;

  /// جای منطقی فعلی کارت (برای بازچینی هنگام resize).
  int slotIndex = 0;
  int slotCount = 1;

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & size.toSize();

    // سایهٔ نرم — دو لایهٔ محو (ارزان، بدون MaskFilter سنگین)
    final shadowPaint = Paint()..color = const Color(0x33000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(size.x * 0.020, size.y * 0.045),
          Radius.circular(CardRenderer.radius(size.x))),
      shadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(size.x * 0.008, size.y * 0.018),
          Radius.circular(CardRenderer.radius(size.x))),
      Paint()..color = const Color(0x26000000),
    );

    if (playable || !faceUp) {
      // رندر عادی
      _paintBody(canvas, rect);
    } else {
      // کارت غیرمجاز: کمی کم‌رنگ‌تر (با پوشش نیمه‌شفاف)
      _paintBody(canvas, rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            rect, Radius.circular(CardRenderer.radius(size.x))),
        Paint()..color = const Color(0x550A0F16),
      );
    }
  }

  void _paintBody(Canvas canvas, Rect rect) {
    if (faceUp) {
      CardRenderer.paintFront(canvas, rect, card);
    } else {
      CardRenderer.paintBack(canvas, rect, cardBackStyle);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (interactive && onTapped != null) {
      onTapped!(card);
    }
    event.handled = interactive;
  }

  @override
  void update(double dt) {
    super.update(dt);
    updateMotion(dt);
  }

  @override
  String toString() => 'CardComponent(${card.id}, faceUp=$faceUp)';
}
