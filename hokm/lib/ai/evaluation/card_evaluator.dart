import '../../game_engine/models/playing_card.dart';
import '../../game_engine/models/rank.dart';
import '../../game_engine/models/suit.dart';

/// ارزیابی ارزش تکی کارت‌ها — توابع خالص.
abstract final class CardEvaluator {
  /// امتیاز پایهٔ هر رتبه برای ارزیابی دست (فقط کارت‌های باارزش امتیاز دارند).
  static int rankWeight(Rank rank) => switch (rank) {
        Rank.ace => 8,
        Rank.king => 5,
        Rank.queen => 3,
        Rank.jack => 2,
        Rank.ten => 1,
        _ => 0,
      };

  /// قدرت کارت در مقایسهٔ مستقیم — رتبهٔ عددی.
  static int rawStrength(PlayingCard card) => card.rank.value;

  /// ارزش کارت برای «دور انداختن»: هر چه کمتر، برای دادن به حریف بهتر.
  /// (کوچک‌ترین کارتِ بی‌ارزش بهترین انتخاب برای رها کردن است.)
  static int dumpValue(PlayingCard card, Suit trump) {
    final trumpPenalty = card.suit == trump ? 100 : 0;
    return trumpPenalty + card.rank.value;
  }

  /// مرتب‌سازی از ضعیف به قوی.
  static List<PlayingCard> sortedAscending(List<PlayingCard> cards) {
    final copy = List<PlayingCard>.of(cards)
      ..sort((a, b) => a.rank.value.compareTo(b.rank.value));
    return copy;
  }
}
