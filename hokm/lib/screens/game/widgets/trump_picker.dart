import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/app_theme.dart';
import '../../../game_engine/models/playing_card.dart';
import '../../../game_engine/models/suit.dart';
import '../../../game/cards/card_renderer.dart';
import 'suit_icon.dart';

/// اورلی انتخاب حکم وقتی حاکم انسان است — نمایش ۵ کارت اولیه و چهار خال.
class TrumpPickerOverlay extends StatelessWidget {
  const TrumpPickerOverlay({
    super.key,
    required this.previewCards,
    required this.onSelected,
  });

  final List<PlayingCard> previewCards;
  final ValueChanged<Suit> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.72),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 26),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.gold.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  AppStrings.chooseTrumpTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.gold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  AppStrings.chooseTrumpHint,
                  style: TextStyle(fontSize: 12.5, color: Colors.white70),
                ),
                const SizedBox(height: 16),

                // پیش‌نمایش ۵ کارت
                SizedBox(
                  height: 74,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < previewCards.length; i++)
                        Align(
                          widthFactor: 0.62,
                          child: Transform.rotate(
                            angle: (i - 2) * 0.045,
                            child: _MiniCardFace(card: previewCards[i]),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // چهار خال
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final suit in Suit.values)
                      _SuitChoiceButton(suit: suit, onTap: () => onSelected(suit)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuitChoiceButton extends StatelessWidget {
  const _SuitChoiceButton({required this.suit, required this.onTap});

  final Suit suit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF262E3B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              SuitIcon(suit: suit, size: 30),
              const SizedBox(height: 6),
              Text(
                suit.faName,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// کارت مینیاتوری در دیالوگ انتخاب حکم — همان رندر اصلی کارت.
class _MiniCardFace extends StatelessWidget {
  const _MiniCardFace({required this.card});

  final PlayingCard card;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(52, 74),
      painter: _MiniCardPainter(card),
    );
  }
}

class _MiniCardPainter extends CustomPainter {
  _MiniCardPainter(this.card);

  final PlayingCard card;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
        rect, Radius.circular(CardRenderer.radius(size.width)));
    canvas.drawShadow(Path()..addRRect(rrect), Colors.black, 4, true);
    CardRenderer.paintFront(canvas, rect, card);
  }

  @override
  bool shouldRepaint(_MiniCardPainter old) => old.card != card;
}
