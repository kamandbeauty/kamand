import '../../game_engine/models/playing_card.dart';
import '../../game_engine/models/suit.dart';
import '../../game_engine/state/game_enums.dart';
import '../evaluation/hand_evaluator.dart';

/// انتخاب خال حکم توسط حاکم AI — هرگز تصادفی نیست.
class HukumSelector {
  const HukumSelector();

  /// انتخاب حکم از روی دستِ پنج‌تایی اولیهٔ حاکم.
  ///
  /// همهٔ سطوح از ارزیابی قدرت استفاده می‌کنند؛ تفاوت Easy فقط
  /// در دقت کمتر (نادیده گرفتن بخشی از معیارها) است.
  Suit select(List<PlayingCard> previewHand, AiDifficulty difficulty) {
    switch (difficulty) {
      case AiDifficulty.easy:
        return _selectSimple(previewHand);
      case AiDifficulty.normal:
      case AiDifficulty.hard:
        return HandEvaluator.bestTrumpSuit(previewHand);
    }
  }

  /// Easy: فقط تعداد کارت هر خال + امتیاز سادهٔ کارت‌های بزرگ.
  Suit _selectSimple(List<PlayingCard> hand) {
    var best = Suit.values.first;
    var bestScore = -1;
    for (final suit in Suit.values) {
      final cards = hand.where((c) => c.suit == suit).toList();
      var score = cards.length * 10;
      for (final c in cards) {
        if (c.rank.value >= 11) score += 2;
      }
      if (score > bestScore) {
        bestScore = score;
        best = suit;
      }
    }
    return best;
  }
}
