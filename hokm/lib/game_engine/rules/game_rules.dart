import '../models/playing_card.dart';
import '../models/trick.dart';
import '../models/suit.dart';

/// قوانین اصلی حکم — توابع خالص و قابل تست.
///
/// قانون نوبت:
/// ۱. اگر خال زمینه را داری، حتماً همان را بازی کن.
/// ۲. اگر نداری، آزاد هستی (می‌توانی حکم بزنی یا خال دیگری بیاندازی).
abstract final class GameRules {
  /// کارت‌های مجاز برای بازی در این نوبت.
  ///
  /// اگر دور خالی است (شروع‌کنندهٔ دور هستی) همهٔ کارت‌ها مجازند.
  static List<PlayingCard> legalPlays(
    List<PlayingCard> hand,
    Trick currentTrick,
  ) {
    if (currentTrick.isEmpty) return List<PlayingCard>.of(hand);
    final led = currentTrick.ledSuit!;
    final follow = hand.where((c) => c.suit == led).toList();
    if (follow.isNotEmpty) return follow;
    return List<PlayingCard>.of(hand);
  }

  /// آیا بازی این کارت مجاز است؟
  static bool isLegalPlay(
    PlayingCard card,
    List<PlayingCard> hand,
    Trick currentTrick,
  ) {
    return legalPlays(hand, currentTrick).contains(card);
  }

  /// برندهٔ یک دورِ کامل.
  ///
  /// اگر لااقل یک حکم در دور باشد، بالاترین حکم می‌برد؛
  /// در غیر این صورت بالاترین کارت از خال زمینه.
  static PlayedCard trickWinner(Trick trick, Suit trump) =>
      trick.currentWinner(trump);
}
