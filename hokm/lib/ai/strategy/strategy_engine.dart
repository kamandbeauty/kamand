import 'dart:math';

import '../../game_engine/models/playing_card.dart';
import '../../game_engine/models/suit.dart';
import '../../game_engine/state/game_enums.dart';
import '../ai_view.dart';
import '../evaluation/card_evaluator.dart';
import '../evaluation/trick_evaluator.dart';
import '../memory/memory_tracker.dart';
import '../probability/probability_engine.dart';

/// موتور تصمیم‌گیری AI — قلب استراتژی حکم.
///
/// ## اصول طراحی
/// * هر تصمیم از میان کارت‌های **مجاز** ([legalPlays]) است → تضمین قانون.
/// * AI فقط [AiGameView] و مشتقاتش را می‌بیند → بدون تقلب.
/// * سه سطح با گرادیان واقعی:
///   - Easy: تصمیم‌های ساده، گاهی ضعیف، اما همیشه قانونی.
///   - Normal: ارزش کارت + حافظهٔ کارت‌های رفته + برد ارزان + همکاری ساده.
///   - Hard: شمارش کامل، استنتاج خالِ خالی، احتمال، ذخیرهٔ حکم،
///     برنامه‌ریزی بر اساس تعداد دورهای لازم برای بردن دست.
class StrategyEngine {
  StrategyEngine({required this.difficulty, Random? random})
      : _random = random ?? Random();

  final AiDifficulty difficulty;
  final Random _random;

  /// انتخاب کارت برای بازی.
  ///
  /// [view] نمای محدود (ضدتقلب) و [legalPlays] خروجی قوانین بازی است.
  PlayingCard chooseCard(AiGameView view, List<PlayingCard> legalPlays) {
    assert(legalPlays.isNotEmpty, 'AI received no legal plays');
    if (legalPlays.length == 1) return legalPlays.single;

    final chosen = switch (difficulty) {
      AiDifficulty.easy => _chooseEasy(view, legalPlays),
      AiDifficulty.normal => _chooseNormal(view, legalPlays),
      AiDifficulty.hard => _chooseHard(view, legalPlays),
    };
    assert(legalPlays.contains(chosen), 'AI chose an illegal card');
    return chosen;
  }

  // ================================================================
  // Easy — ساده و گاهی ضعیف، اما قانونی
  // ================================================================

  PlayingCard _chooseEasy(AiGameView view, List<PlayingCard> legal) {
    final sorted = CardEvaluator.sortedAscending(legal);
    final roll = _random.nextDouble();
    if (view.isLeading) {
      // شروع‌کننده: نصف‌وقت ضعیف‌ترین، گاهی تصادفی، به‌ندرت قوی‌ترین.
      if (roll < 0.50) return sorted.first;
      if (roll < 0.85) return sorted[_random.nextInt(sorted.length)];
      return sorted.last;
    }
    // در میانهٔ دور: بیشتر رها کردنِ کوچک‌ترین، گاهی اتلاف کارت بزرگ.
    if (roll < 0.70) return sorted.first;
    if (roll < 0.90) return sorted[_random.nextInt(sorted.length)];
    return sorted.last;
  }

  // ================================================================
  // Normal — منطقی، با حافظهٔ کارت‌های رفته و همکاری ساده
  // ================================================================

  PlayingCard _chooseNormal(AiGameView view, List<PlayingCard> legal) {
    final memory = MemoryTracker.fromView(view);
    final evaluator = TrickEvaluator(trick: view.currentTrick, trump: view.trump);

    if (view.isLeading) {
      return _leadNormal(view, legal, memory);
    }

    if (evaluator.isPartnerWinning(view.mySeat)) {
      // یار دارد می‌برد → کم‌ارزش‌ترین کارت را بده.
      return _lowestDump(legal, view.trump);
    }

    if (evaluator.isOpponentWinning(view.mySeat)) {
      final cheap = evaluator.cheapestWinner(legal);
      if (cheap != null) return cheap; // برد با کمترین هزینه
    }

    return _lowestDump(legal, view.trump);
  }

  PlayingCard _leadNormal(
      AiGameView view, List<PlayingCard> legal, MemoryTracker memory) {
    // کارت‌هایی که بالاترینِ باقی‌ماندهٔ خالشان‌اند (برندهٔ قطعی به نظر می‌رسند).
    final winners = legal.where(memory.isHighestRemaining).toList();
    if (winners.isNotEmpty) {
      winners.sort((a, b) => b.rank.value.compareTo(a.rank.value));
      return winners.first;
    }
    // در غیر این صورت کوچک‌ترین کارتِ طولانی‌ترین خال.
    final trumps = legal.where((c) => c.suit == view.trump).toList();
    final plain = legal.where((c) => c.suit != view.trump).toList();
    final pool = plain.isNotEmpty ? plain : trumps;
    pool.sort((a, b) {
      final countA = _countSuit(view.myHand, a.suit);
      final countB = _countSuit(view.myHand, b.suit);
      if (countA != countB) return countB.compareTo(countA);
      return a.rank.value.compareTo(b.rank.value);
    });
    return pool.first;
  }

  // ================================================================
  // Hard — شمارش کامل + احتمال + همکاری تیمی + برنامه‌ریزی
  // ================================================================

  PlayingCard _chooseHard(AiGameView view, List<PlayingCard> legal) {
    final memory = MemoryTracker.fromView(view);
    final prob = ProbabilityEngine(view: view, memory: memory);
    final evaluator = TrickEvaluator(trick: view.currentTrick, trump: view.trump);

    if (view.isLeading) {
      return _leadHard(view, legal, memory, prob);
    }

    // --- در میانهٔ دور ---
    if (evaluator.isPartnerWinning(view.mySeat)) {
      return _lowestDump(legal, view.trump);
    }

    if (evaluator.isOpponentWinning(view.mySeat)) {
      final cheap = evaluator.cheapestWinner(legal);
      if (cheap != null) {
        if (_shouldTakeTrick(view, cheap, legal, memory, prob)) {
          return cheap;
        }
      }
    }

    return _lowestDump(legal, view.trump);
  }

  /// آیا بردن این دور با [winningCard] ارزش دارد یا کارت را ذخیره کنیم؟
  bool _shouldTakeTrick(
    AiGameView view,
    PlayingCard winningCard,
    List<PlayingCard> legal,
    MemoryTracker memory,
    ProbabilityEngine prob,
  ) {
    // برد قطعیِ دست را هرگز ول نمی‌کنیم.
    if (view.tricksWonUs == 6) return true;
    // اگر حریف به ۶ رسیده، هر دور حیاتی است.
    if (view.tricksWonThem >= 6) return true;

    final isTrump = winningCard.suit == view.trump;
    if (!isTrump) return true; // برد با خال غیر حکم ارزان است.

    // بردن با حکمِ خیلی بزرگ وقتی حریف نزدیکِ بردِ دست نیست:
    // اگر کارتِ بی‌ارزشی برای رها کردن داریم، حکم بزرگ را ذخیره می‌کنیم —
    // مگر اینکه حکم‌های حریف تمام‌نشده و فرصت برش بعدی کم باشد.
    final bigTrump = winningCard.rank.value >= 12; // Q, K, A
    if (!bigTrump) return true;

    final hasJunk = legal.any((c) =>
        c.suit != view.trump && c.rank.value <= 9 &&
        !memory.isHighestRemaining(c));
    if (!hasJunk) return true;

    // اگر حریف حکم تمام کرده باشد، نگه‌داشتن حکم بزرگ فقط برای قطع کردن
    // دورهای آخر لازم است؛ در غیر این صورت تیم‌مان به آن نیاز دارد.
    final midGame = view.tricksWonUs <= 2 && view.tricksWonThem <= 2;
    if (midGame) return false;
    return true;
  }

  PlayingCard _leadHard(
    AiGameView view,
    List<PlayingCard> legal,
    MemoryTracker memory,
    ProbabilityEngine prob,
  ) {
    final closeOut = view.tricksWonUs >= 6; // یکی مانده به بردن دست
    final danger = view.tricksWonThem >= 6; // حریف یکی مانده

    PlayingCard strongest(List<PlayingCard> cards) {
      final copy = List<PlayingCard>.of(cards)
        ..sort((a, b) => b.rank.value.compareTo(a.rank.value));
      return copy.first;
    }

    // برنده‌های قطعی بر اساس حافظه: بالاترین کارتِ باقی‌ماندهٔ خالشان.
    final allWinners = legal.where(memory.isHighestRemaining).toList();
    // زیرمجموعهٔ «امن»: حکم است یا حریف عملاً حکمی ندارد که پوش بدهد.
    final safeWinners = allWinners
        .where((c) =>
            c.suit == view.trump ||
            prob.chanceOpponentsHaveTrump() < 0.05)
        .toList();

    // ۱) حالت پایان‌بخشی/بحران: باید دور را گرفت؛ حتی با ریسک برش حکم.
    if (closeOut || danger) {
      if (safeWinners.isNotEmpty) return strongest(safeWinners);
      if (allWinners.isNotEmpty) return strongest(allWinners);
      // هیچ برندهٔ قطعی نیست → قوی‌ترین کارتِ موجود (بهترین شانس).
      return strongest(legal);
    }

    // ۲) لیّد به خالِ خالیِ یار (یار می‌تواند حکم بزند) — وسط بازی.
    if (view.roundTricksRemaining() > 3) {
      for (final suit in Suit.values) {
        if (suit == view.trump) continue;
        if (!prob.partnerDefinitelyVoid(suit)) continue;
        final mine = legal.where((c) => c.suit == suit).toList()
          ..sort((a, b) => a.rank.value.compareTo(b.rank.value));
        if (mine.isNotEmpty) return mine.first;
      }
    }

    // ۳) نقد کردن برنده‌های امن (از قوی‌ترین‌ها شروع می‌کنیم تا خال را تمیز کنیم).
    if (safeWinners.isNotEmpty) return strongest(safeWinners);

    // ۴) کشیدن حکم: اگر بالاترین حکمِ باقی‌مانده نزد ماست،
    //    با آن لیّد می‌کنیم تا حکم‌های حریف سوزانده شود.
    final myTrumps = legal.where((c) => c.suit == view.trump).toList()
      ..sort((a, b) => b.rank.value.compareTo(a.rank.value));
    if (myTrumps.isNotEmpty &&
        prob.chanceOpponentsHaveTrump() > 0.01 &&
        memory.isHighestRemaining(myTrumps.first)) {
      return myTrumps.first;
    }

    // ۵) توسعهٔ خال طولانی: کوچک‌ترین کارتِ بلندترین خالِ غیر حکم.
    final plain = legal.where((c) => c.suit != view.trump).toList();
    if (plain.isNotEmpty) {
      plain.sort((a, b) {
        final countA = _countSuit(view.myHand, a.suit);
        final countB = _countSuit(view.myHand, b.suit);
        if (countA != countB) return countB.compareTo(countA);
        return a.rank.value.compareTo(b.rank.value);
      });
      return plain.first;
    }

    return _lowestDump(legal, view.trump);
  }

  // ================================================================
  // ابزارهای مشترک
  // ================================================================

  /// کم‌ارزش‌ترین کارت برای رها کردن (کوچک و غیر حکم).
  PlayingCard _lowestDump(List<PlayingCard> legal, Suit trump) {
    final sorted = CardEvaluator.sortedAscending(legal);
    return sorted.reduce((a, b) =>
        CardEvaluator.dumpValue(a, trump) <= CardEvaluator.dumpValue(b, trump)
            ? a
            : b);
  }

  int _countSuit(List<PlayingCard> hand, Suit suit) =>
      hand.where((c) => c.suit == suit).length;
}
