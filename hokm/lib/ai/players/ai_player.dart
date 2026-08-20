import 'dart:math';

import '../../game_engine/models/playing_card.dart';
import '../../game_engine/models/suit.dart';
import '../../game_engine/models/trick.dart';
import '../../game_engine/rules/game_rules.dart';
import '../../game_engine/state/game_enums.dart';
import '../../game_engine/state/game_state.dart';
import '../ai_view.dart';
import '../strategy/hukum_selector.dart';
import '../strategy/strategy_engine.dart';

/// نمایندهٔ یک بازیکن AI — facade تمام بخش‌های تصمیم‌گیری.
///
/// این کلاس هرگز به دست بازیکنان دیگر دسترسی نمی‌گیرد؛ تنها ورودی‌اش
/// [AiGameView] است که عمداً حاوی اطلاعات عمومی + دستِ خودِ AI است.
class AiPlayer {
  AiPlayer({
    required this.seat,
    required this.difficulty,
    Random? random,
    HukumSelector? hukumSelector,
  })  : _strategy =
            StrategyEngine(difficulty: difficulty, random: random ?? Random()),
        _hukumSelector = hukumSelector ?? const HukumSelector();

  final Seat seat;
  final AiDifficulty difficulty;

  final StrategyEngine _strategy;
  final HukumSelector _hukumSelector;

  /// انتخاب کارت برای نوبت فعلی AI.
  ///
  /// اعتبارسنجی نهایی با همان [GameRules] موتور انجام می‌شود —
  /// لایهٔ دوگانهٔ اطمینان از قانونی بودن حرکت.
  PlayingCard chooseCard(GameState state) {
    final view = AiGameView.fromState(state, seat);
    final legal = GameRules.legalPlays(
      state.playerAt(seat).hand,
      state.currentTrick ?? Trick(leaderSeat: seat),
    );
    if (legal.isEmpty) {
      throw StateError('AI $seat has no legal plays — engine state invalid');
    }
    return _strategy.chooseCard(view, legal);
  }

  /// انتخاب خال حکم وقتی AI حاکم است (از روی ۵ کارت اولیه).
  Suit selectTrump(GameState state) {
    final preview = state.playerAt(seat).hand;
    return _hukumSelector.select(preview, difficulty);
  }
}
