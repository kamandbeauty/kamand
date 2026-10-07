/// رگرسیون: اعلام حکم با جوکر و جلوگیری از شروعِ راند بعد از پایانِ بازی.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelem/game/engine.dart';
import 'package:shelem/model/card.dart';

/// موتوری که حاکمش جوکر را به‌عنوان اولین برگ انداخته و هنوز حکم نداده است.
ShelemEngine _awaitingJoker() {
  final ShelemEngine e = ShelemEngine(
    config: const GameConfig(withJokers: true, targetScore: 1000000),
    random: Random(3),
  )..startRound();

  e.placeBid(e.config.minBid);
  while (e.phase == GamePhase.bidding) {
    e.passBid();
  }
  expect(e.phase, GamePhase.kitty);
  e.takeKitty();

  final int h = e.hakem!;
  const PlayingCard red = PlayingCard(Suit.joker, kRedJokerRank);
  for (int p = 0; p < 4 && !e.hands[h].contains(red); p++) {
    if (p != h && e.hands[p].remove(red)) {
      e.hands[p].add(e.hands[h].removeLast());
      e.hands[h].add(red);
    }
  }
  expect(e.hands[h].contains(red), isTrue);

  e.discardCards(
    e.hands[h]
        .where((PlayingCard c) => !c.isJoker)
        .take(e.config.kittySize)
        .toList(),
  );
  expect(e.phase, GamePhase.declaringTrump);
  e.playCard(h, red);
  return e;
}

void main() {
  group('شروع با جوکر', () {
    test('تا اعلام نشدنِ حکم، برگِ دیگری بازی نمی‌شود', () {
      final ShelemEngine e = _awaitingJoker();
      final int h = e.hakem!;
      expect(e.awaitingJokerTrump, isTrue);
      expect(e.trump, isNull);
      expect(e.trick.length, 1);
      for (final PlayingCard c in e.hands[h]) {
        expect(e.canPlay(h, c), isFalse);
      }
      expect(() => e.playCard(h, e.hands[h].first), throwsStateError);
    });

    test('بعد از اعلام حکم، نوبت به نفرِ بعدی می‌رسد', () {
      final ShelemEngine e = _awaitingJoker();
      final int h = e.hakem!;
      e.declareTrumpSuit(Suit.hearts);
      expect(e.trump, Suit.hearts);
      expect(e.phase, GamePhase.playing);
      expect(e.turn, nextPlayer(h));
      expect(e.trick.length, 1);
      expect(e.awaitingJokerTrump, isFalse);
    });
  });

  group('پایانِ بازی', () {
    test('بعد از پایان بازی، راندِ تازه شروع نمی‌شود', () {
      final ShelemEngine e = ShelemEngine(random: Random(1))..startRound();
      e.phase = GamePhase.gameOver;
      final int round = e.round;
      e.startRound();
      expect(e.round, round);
      expect(e.phase, GamePhase.gameOver);
    });
  });
}
