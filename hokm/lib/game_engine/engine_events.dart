import 'managers/deal_manager.dart';
import 'managers/hukum_manager.dart';
import 'models/playing_card.dart';
import 'models/suit.dart';
import 'models/trick.dart';
import 'scoring/score_manager.dart';
import 'state/game_enums.dart';

/// رویدادهای موتور بازی.
///
/// موتور کاملاً synchronous کار می‌کند و از طریق این رویدادها به
/// لایهٔ UI اطلاع می‌دهد؛ لایهٔ انیمیشن با خواندن آن‌ها، حرکت‌ها را
/// با ریتم مناسب نمایش می‌دهد بدون آنکه منطق بازی به انیمیشن وابسته شود.
sealed class GameEvent {
  const GameEvent();
}

/// مسابقه شروع شد.
class MatchStartedEvent extends GameEvent {
  const MatchStartedEvent({required this.humanSeat, required this.matchTarget});

  final Seat humanSeat;
  final int matchTarget;
}

/// حاکم اولیه تعیین شد (پخش کارت تا اولین آس).
class HakimDeterminedEvent extends GameEvent {
  const HakimDeterminedEvent({
    required this.hakim,
    required this.dealtCards,
  });

  final Seat hakim;

  /// کارت‌هایی که برای تعیین حاکم پخش شدند (برای انیمیشن).
  final List<PlayedForHakim> dealtCards;
}

/// یک دست جدید آغاز شد.
class RoundStartedEvent extends GameEvent {
  const RoundStartedEvent({required this.roundNumber, required this.hakim});

  final int roundNumber;
  final Seat hakim;
}

/// پنج کارت اولیه پخش شد.
class InitialDealEvent extends GameEvent {
  const InitialDealEvent({required this.steps});

  final List<DealStep> steps;
}

/// نوبت انتخاب حکم است — حاکم باید خال را انتخاب کند.
class TrumpSelectionRequestedEvent extends GameEvent {
  const TrumpSelectionRequestedEvent({
    required this.hakim,
    required this.isHuman,
    required this.previewCards,
  });

  final Seat hakim;
  final bool isHuman;

  /// ۵ کارتی که حاکم برای انتخاب حکم دیده است.
  final List<PlayingCard> previewCards;
}

/// حکم انتخاب شد.
class TrumpSelectedEvent extends GameEvent {
  const TrumpSelectedEvent({required this.by, required this.trump});

  final Seat by;
  final Suit trump;
}

/// یک مرحله از پخش باقی کارت‌ها انجام شد (۴ تایی اول یا دوم).
class DealBatchEvent extends GameEvent {
  const DealBatchEvent({required this.batchIndex, required this.steps});

  /// صفر یا یک.
  final int batchIndex;
  final List<DealStep> steps;
}

/// پخش کامل شد و بازی دست آغاز می‌شود.
class DealCompletedEvent extends GameEvent {
  const DealCompletedEvent();
}

/// نوبت به یک بازیکن رسید.
class TurnChangedEvent extends GameEvent {
  const TurnChangedEvent({
    required this.seat,
    required this.isHuman,
    required this.legalPlays,
    this.isTrickLeader = false,
  });

  final Seat seat;
  final bool isHuman;
  final List<PlayingCard> legalPlays;
  final bool isTrickLeader;
}

/// یک کارت بازی شد.
class CardPlayedEvent extends GameEvent {
  const CardPlayedEvent({
    required this.seat,
    required this.card,
    required this.trick,
    this.remainingInHand = 0,
  });

  final Seat seat;
  final PlayingCard card;

  /// دور پس از افزودن این کارت.
  final Trick trick;
  final int remainingInHand;
}

/// یک دور کامل شد و برندهٔ آن مشخص است.
class TrickCompletedEvent extends GameEvent {
  const TrickCompletedEvent({
    required this.trick,
    required this.winnerSeat,
    required this.tricksWon,
  });

  final Trick trick;
  final Seat winnerSeat;

  /// تعداد دورهای برده‌شدهٔ هر تیم تا این لحظه [team0, team1].
  final List<int> tricksWon;
}

/// دست تمام شد.
class RoundEndedEvent extends GameEvent {
  const RoundEndedEvent({
    required this.result,
    required this.tricksWon,
    required this.matchScores,
    required this.nextHakim,
  });

  final RoundResult result;
  final List<int> tricksWon;

  /// امتیاز مسابقهٔ تیم‌ها پس از این دست.
  final List<int> matchScores;

  /// حاکم دست بعد.
  final Seat nextHakim;
}

/// مسابقه تمام شد.
class MatchEndedEvent extends GameEvent {
  const MatchEndedEvent({
    required this.winnerTeamIndex,
    required this.matchScores,
  });

  final int winnerTeamIndex;
  final List<int> matchScores;
}
