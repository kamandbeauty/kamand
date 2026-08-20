import '../../game_engine/models/playing_card.dart';
import '../../game_engine/models/trick.dart';
import '../../game_engine/models/suit.dart';
import '../../game_engine/state/game_enums.dart';

/// ارزیابی وضعیت دورِ جاری از دید یک بازیکن.
class TrickEvaluator {
  const TrickEvaluator({required this.trick, required this.trump});

  final Trick trick;
  final Suit trump;

  /// برندهٔ کنونی دور (null اگر هنوز کارتی نیامده).
  PlayedCard? get currentWinner =>
      trick.isEmpty ? null : trick.currentWinner(trump);

  /// آیا در حال حاضر یارِ [seat] برندهٔ دور است؟
  bool isPartnerWinning(Seat seat) {
    final winner = currentWinner;
    return winner != null && winner.seat.isPartnerOf(seat);
  }

  /// آیا در حال حاضر حریفِ [seat] برندهٔ دور است؟
  bool isOpponentWinning(Seat seat) {
    final winner = currentWinner;
    return winner != null && !winner.seat.isPartnerOf(seat) && winner.seat != seat;
  }

  /// آیا [card] با این وضعیت دور را می‌برد؟
  bool wouldWin(PlayingCard card) {
    if (trick.isEmpty) return true;
    return Trick.beats(card, currentWinner!.card, trump);
  }

  /// ارزان‌ترین کارت از [candidates] که دور را می‌برد (null اگر هیچ‌کدام).
  ///
  /// «ارزان‌ترین» = کم‌رتبه‌ترین کارتِ برنده؛ حکمِ بالاتر از حد لزوم هدر نمی‌رود.
  PlayingCard? cheapestWinner(List<PlayingCard> candidates) {
    PlayingCard? best;
    for (final c in candidates) {
      if (!wouldWin(c)) continue;
      final cIsTrump = c.suit == trump;
      if (best == null) {
        best = c;
      } else {
        final bestIsTrump = best.suit == trump;
        // ترجیح: غیرحکمِ برنده > حکمِ برنده؛ در هر گروه، کم‌رتبه‌تر.
        if (bestIsTrump && !cIsTrump) {
          best = c;
        } else if (bestIsTrump == cIsTrump &&
            c.rank.value < best.rank.value) {
          best = c;
        }
      }
    }
    return best;
  }
}
