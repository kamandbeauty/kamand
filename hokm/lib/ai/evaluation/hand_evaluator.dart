import '../../game_engine/models/playing_card.dart';
import '../../game_engine/models/rank.dart';
import '../../game_engine/models/suit.dart';
import 'card_evaluator.dart';

/// ارزیابی دست — برای انتخاب حکم و برنامه‌ریزی کلی بازی.
abstract final class HandEvaluator {
  /// امتیاز یک خال به‌عنوان کاندید حکم:
  /// تعداد کارت + کارت‌های بزرگ + ساختار (زنجیرهٔ بالا).
  static int suitTrumpScore(List<PlayingCard> hand, Suit suit) {
    final cards = hand.where((c) => c.suit == suit).toList();
    if (cards.isEmpty) return 0;
    var score = cards.length * 12; // برتری تعداد
    for (final c in cards) {
      score += CardEvaluator.rankWeight(c.rank);
    }
    // پاداش داشتن زنجیرهٔ بالای خال (A+K، A+K+Q...).
    final hasAce = cards.any((c) => c.rank == Rank.ace);
    final hasKing = cards.any((c) => c.rank == Rank.king);
    final hasQueen = cards.any((c) => c.rank == Rank.queen);
    if (hasAce) score += 4;
    if (hasAce && hasKing) score += 4;
    if (hasAce && hasKing && hasQueen) score += 3;
    // پاداش طول: خال‌های ۴+ با توجه به دستِ پنج‌تایی اولیه بسیار ارزشمندند.
    if (cards.length >= 3) score += (cards.length - 2) * 3;
    return score;
  }

  /// بهترین خال به‌عنوان حکم بر اساس امتیاز.
  static Suit bestTrumpSuit(List<PlayingCard> previewHand) {
    Suit best = Suit.values.first;
    var bestScore = -1;
    for (final suit in Suit.values) {
      final score = suitTrumpScore(previewHand, suit);
      if (score > bestScore) {
        bestScore = score;
        best = suit;
      }
    }
    return best;
  }

  /// تخمین تعداد دورهایی که این دست (با حکمِ [trump]) احتمالاً می‌برد.
  /// تخمین محافظه‌کارانه برای برنامه‌ریزی: آس‌ها، شاه‌های پشت‌به‌آس،
  /// و حکم‌های قوی شمارش می‌شوند.
  static double expectedTricks(List<PlayingCard> hand, Suit trump) {
    var expected = 0.0;
    final bySuit = <Suit, List<PlayingCard>>{};
    for (final c in hand) {
      bySuit.putIfAbsent(c.suit, () => <PlayingCard>[]).add(c);
    }
    for (final entry in bySuit.entries) {
      final cards = entry.value
        ..sort((a, b) => b.rank.value.compareTo(a.rank.value));
      final isTrump = entry.key == trump;
      for (var i = 0; i < cards.length; i++) {
        final rank = cards[i].rank;
        if (rank == Rank.ace) {
          expected += isTrump ? 1.0 : 0.9;
        } else if (rank == Rank.king) {
          // شاه وقتی مطمئن است که آس در دست خودمان است.
          if (cards.any((c) => c.rank == Rank.ace) || isTrump) {
            expected += isTrump ? 0.85 : 0.55;
          } else {
            expected += 0.30;
          }
        } else if (isTrump && rank.value >= Rank.queen.value) {
          expected += 0.55;
        }
      }
      // حکم‌های اضافی (طول) ارزش پوش دارند.
      if (isTrump && cards.length >= 4) {
        expected += (cards.length - 3) * 0.35;
      }
    }
    return expected;
  }

  /// ضعیف‌ترین خالِ دست (برای «دور انداختن»): کم‌تعداد و بی‌بزرگ.
  /// null یعنی دست فقط حکم دارد.
  static Suit? weakestPlainSuit(List<PlayingCard> hand, Suit trump) {
    Suit? weakest;
    var weakestScore = 1 << 30;
    for (final suit in Suit.values) {
      if (suit == trump) continue;
      final cards = hand.where((c) => c.suit == suit).toList();
      if (cards.isEmpty) continue;
      var score = cards.length * 10;
      for (final c in cards) {
        score += CardEvaluator.rankWeight(c.rank) * 2 + c.rank.value;
      }
      if (score < weakestScore) {
        weakestScore = score;
        weakest = suit;
      }
    }
    return weakest;
  }
}
