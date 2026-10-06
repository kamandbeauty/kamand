/// ابزار شبیه‌سازی: اجرای راندهای کامل فقط با ربات‌ها.
library;

import 'dart:math';

import 'package:shelem/ai/bot.dart';
import 'package:shelem/game/engine.dart';
import 'package:shelem/model/card.dart';
import 'package:shelem/model/enums.dart';

/// یک برگ بازی می‌کند (همان منطقی که کنترلر در اپ استفاده می‌کند).
void botStep(ShelemEngine e, Difficulty d, Random r) {
  switch (e.phase) {
    case GamePhase.dealing:
      e.startRound();
    case GamePhase.bidding:
      final int? bid = ShelemBot.chooseBid(e, e.bidder, d, rng: r);
      if (bid == null) {
        e.passBid();
      } else {
        e.placeBid(bid);
      }
    case GamePhase.kitty:
      e.takeKitty();
    case GamePhase.discarding:
      final List<PlayingCard> hand = e.hands[e.hakem!];
      final Suit trump = ShelemBot.bestTrump(hand);
      e.discardCards(
        ShelemBot.chooseDiscards(hand, e.config.kittySize, trump),
      );
    case GamePhase.declaringTrump:
      final int p = e.turn;
      final Suit suit = ShelemBot.bestTrump(e.hands[p]);
      final List<PlayingCard> ofSuit =
          e.hands[p].where((PlayingCard c) => c.suit == suit).toList()
            ..sort((PlayingCard a, PlayingCard b) => b.rank.compareTo(a.rank));
      final PlayingCard card =
          ofSuit.isNotEmpty ? ofSuit.first : e.legalFor(p).first;
      e.playCard(p, card, declaredTrump: card.isJoker ? suit : null);
    case GamePhase.playing:
      e.playCard(e.turn, ShelemBot.chooseCard(e, e.turn, d, rng: r));
    case GamePhase.trickComplete:
      e.collectTrick();
    case GamePhase.roundComplete:
    case GamePhase.gameOver:
      break;
  }
}

/// یک راند کامل را تا پایان بازی می‌کند.
void playRound(ShelemEngine e, Difficulty d, Random r) {
  e.startRound();
  int guard = 0;
  while (e.phase != GamePhase.roundComplete &&
      e.phase != GamePhase.gameOver &&
      guard < 5000) {
    botStep(e, d, r);
    guard++;
  }
  if (guard >= 5000) {
    throw StateError('راند تمام نشد (حلقهٔ بی‌پایان) در فاز ${e.phase}');
  }
}

/// بررسی‌های پایه‌ای که در پایان هر راند باید درست باشند.
void assertRoundInvariants(ShelemEngine e, void Function(bool, String) check) {
  final List<int> pts = e.currentPoints();
  check(
    pts[0] + pts[1] == e.config.totalPoints,
    'مجموع امتیاز راند باید ${e.config.totalPoints} باشد ولی ${pts[0] + pts[1]} شد',
  );
  check(
    e.tricksWon[0] + e.tricksWon[1] == e.config.handSize,
    'تعداد دست‌ها باید ${e.config.handSize} باشد',
  );
  check(
    e.hands.every((List<PlayingCard> h) => h.isEmpty),
    'دست همهٔ بازیکن‌ها باید خالی باشد',
  );
  check(e.discards.length == e.config.kittySize, 'تعداد برگ‌های کنارگذاشته');
  check(
    cardPointsOf(e.taken[0]) +
            cardPointsOf(e.taken[1]) +
            cardPointsOf(e.discards) ==
        (e.config.withJokers ? 135 : 100),
    'مجموع امتیاز برگ‌ها',
  );
  check(e.outcome != null, 'نتیجهٔ راند باید محاسبه شده باشد');
}
