import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hokm/game_engine/engine_events.dart';
import 'package:hokm/game_engine/hokm_engine.dart';
import 'package:hokm/game_engine/models/playing_card.dart';
import 'package:hokm/game_engine/models/rank.dart';
import 'package:hokm/game_engine/models/suit.dart';
import 'package:hokm/game_engine/state/game_enums.dart';
import 'package:hokm/game_engine/state/game_state.dart';

import '../helpers/test_driver.dart';

void main() {
  group('Engine lifecycle', () {
    test('startMatch initializes 4 players / 2 teams / phase', () {
      final engine = HokmEngine(random: Random(1));
      final recorder = EventRecorder();
      engine.addListener(recorder);
      engine.startMatch();

      expect(engine.state.players.length, 4);
      expect(engine.state.teams.length, 2);
      expect(engine.state.phase, GamePhase.hakimDetermination);
      expect(recorder.lastOfType<MatchStartedEvent>(), isNotNull);
    });

    test('determineHakim picks the seat receiving the first ace', () {
      for (var seed = 0; seed < 20; seed++) {
        final engine = HokmEngine(random: Random(seed));
        final recorder = EventRecorder();
        engine.addListener(recorder);
        engine.startMatch();
        final result = engine.determineHakim();

        // آخرین کارت پخش‌شده باید آس باشد و متعلق به حاکم.
        expect(result.dealtCards.last.card.rank, Rank.ace);
        expect(result.dealtCards.last.seat, result.hakim);
        // و هیچ آسِ قبلی پخش نشده باشد.
        expect(
          result.dealtCards
              .sublist(0, result.dealtCards.length - 1)
              .any((p) => p.card.rank == Rank.ace),
          isFalse,
        );
        expect(engine.state.hakim, result.hakim);
        expect(recorder.lastOfType<HakimDeterminedEvent>(), isNotNull);
      }
    });

    test('startRound deals 5 cards to each player and requests trump', () {
      final engine = HokmEngine(random: Random(5));
      final recorder = EventRecorder();
      engine.addListener(recorder);
      engine.startMatch();
      engine.determineHakim();
      engine.startRound();

      for (final p in engine.state.players) {
        expect(p.handCount, 5, reason: '${p.seat} should have 5 cards');
      }
      expect(engine.state.phase, GamePhase.awaitingTrumpSelection);

      final request = recorder.lastOfType<TrumpSelectionRequestedEvent>()!;
      expect(request.hakim, engine.state.hakim);
      expect(request.previewCards.length, 5);

      // ترتیب پخش: ۴ مرحلهٔ ۵کارتی، از سمت راست حاکم آغاز و به حاکم ختم می‌شود.
      final deal = recorder.lastOfType<InitialDealEvent>()!;
      expect(deal.steps.length, 4);
      expect(deal.steps.every((s) => s.cards.length == 5), isTrue);
      expect(deal.steps.first.seat, engine.state.hakim!.next);
      expect(deal.steps.last.seat, engine.state.hakim);
    });

    test('selectTrump completes deal: everyone has 13 cards', () {
      final engine = HokmEngine(random: Random(11));
      final recorder = EventRecorder();
      engine.addListener(recorder);
      engine.startMatch();
      engine.determineHakim();
      engine.startRound();
      final hakim = engine.state.hakim!;
      engine.selectTrump(hakim, Suit.hearts);

      for (final p in engine.state.players) {
        expect(p.handCount, 13);
      }
      // هیچ کارتی تکراری نیست.
      final all = <PlayingCard>{
        for (final p in engine.state.players) ...p.hand,
      };
      expect(all.length, 52);
      expect(engine.state.trump, Suit.hearts);
      expect(engine.state.phase, GamePhase.playing);
      expect(engine.state.currentTurn, hakim,
          reason: 'Hakim leads the first trick');
      expect(recorder.lastOfType<DealCompletedEvent>(), isNotNull);
    });

    test('illegal play is rejected (wrong seat and wrong suit)', () {
      final engine = HokmEngine(random: Random(21));
      engine.startMatch();
      engine.determineHakim();
      engine.startRound();
      final hakim = engine.state.hakim!;
      engine.selectTrump(hakim, Suit.diamonds);

      // نوبت اشتباه.
      final other = hakim.next;
      expect(() => engine.playCard(other, engine.state.playerAt(other).hand.first),
          throwsStateError);

      // بازی کردن خال اشتباه وقتی خال زمینه را داریم.
      final leaderHand = engine.state.playerAt(hakim).hand;
      final leadCard = leaderHand.first;
      engine.playCard(hakim, leadCard);
      final nextSeat = engine.state.currentTurn;
      final nextHand = engine.state.playerAt(nextSeat).hand;
      final ledSuit = leadCard.suit;
      final hasLed = nextHand.any((c) => c.suit == ledSuit);
      if (hasLed) {
        final wrong = nextHand.firstWhere((c) => c.suit != ledSuit);
        expect(() => engine.playCard(nextSeat, wrong), throwsArgumentError);
      }
    });

    test('full round: 13 tricks, all 52 cards played, totals consistent', () {
      final driver = AiMatchDriver(seed: 77);
      driver.engine.startMatch();
      driver.engine.determineHakim();
      final tricks = driver.playOneRound();

      expect(tricks[0] + tricks[1], 13);
      expect(
        tricks.any((t) => t >= 7),
        isTrue,
        reason: 'Someone must reach 7 tricks',
      );
      expect(driver.engine.state.isRoundComplete, isTrue);
      expect(driver.engine.state.trickHistory.length, 13);
      for (final p in driver.engine.state.players) {
        expect(p.handCount, 0);
      }
      final roundEnd = driver.recorder.lastOfType<RoundEndedEvent>();
      expect(roundEnd, isNotNull);
      expect(roundEnd!.tricksWon[0] + roundEnd.tricksWon[1], 13);
    });

    test('hakim rotation: stays on win, passes right on loss', () {
      final driver = AiMatchDriver(seed: 31, matchTarget: 50);
      driver.engine.startMatch();
      driver.engine.determineHakim();
      var previousHakim = driver.engine.state.hakim!;

      for (var round = 0; round < 6; round++) {
        driver.playOneRound();
        final event = driver.recorder.lastOfType<RoundEndedEvent>()!;
        final winner = event.result.winnerTeamIndex;
        if (winner == previousHakim.teamIndex) {
          expect(event.nextHakim, previousHakim,
              reason: 'Hakim team won → same hakim');
        } else {
          expect(event.nextHakim, previousHakim.next,
              reason: 'Hakim team lost → hakim passes to the right');
        }
        previousHakim = event.nextHakim;
      }
    });

    test('full match ends and produces a winner', () {
      final driver = AiMatchDriver(seed: 1337);
      final rounds = driver.playFullMatch();
      expect(rounds, greaterThan(0));
      final matchEnd = driver.recorder.lastOfType<MatchEndedEvent>()!;
      expect(matchEnd.winnerTeamIndex, isIn([0, 1]));
      expect(matchEnd.matchScores[matchEnd.winnerTeamIndex],
          greaterThanOrEqualTo(7));
      expect(driver.engine.state.phase, GamePhase.matchEnd);
    });
  });

  group('Save / Load', () {
    test('game state json round-trip is lossless mid-match', () {
      final driver = AiMatchDriver(seed: 909);
      driver.engine.startMatch();
      driver.engine.determineHakim();
      driver.engine.startRound();
      final hakim = driver.engine.state.hakim!;
      driver.engine.selectTrump(hakim, Suit.spades);

      // چند دور بازی کنیم تا state پیچیده شود.
      for (var i = 0; i < 7; i++) {
        final seat = driver.engine.state.currentTurn;
        final card = driver.players[seat]!.chooseCard(driver.engine.state);
        driver.engine.playCard(seat, card);
      }

      final json = driver.engine.state.toJson();
      final restored = GameState.fromJson(json);

      final original = driver.engine.state;
      expect(restored.phase, original.phase);
      expect(restored.currentTurn, original.currentTurn);
      expect(restored.hakim, original.hakim);
      expect(restored.trump, original.trump);
      expect(restored.tricksWon, original.tricksWon);
      expect(restored.roundNumber, original.roundNumber);
      expect(restored.trickHistory.length, original.trickHistory.length);
      for (var i = 0; i < 4; i++) {
        expect(restored.players[i].hand.toSet(),
            original.players[i].hand.toSet(),
            reason: 'hand of seat $i must survive round-trip');
      }
      // سریالایز دوباره باید همان json را بدهد (idempotent).
      expect(restored.toJson(), json);
    });

    test('restored engine can continue the round to completion', () {
      final driver = AiMatchDriver(seed: 555);
      driver.engine.startMatch();
      driver.engine.determineHakim();
      driver.engine.startRound();
      final hakim = driver.engine.state.hakim!;
      driver.engine.selectTrump(hakim, Suit.clubs);

      for (var i = 0; i < 9; i++) {
        final seat = driver.engine.state.currentTurn;
        driver.engine
            .playCard(seat, driver.players[seat]!.chooseCard(driver.engine.state));
      }

      // ذخیره و بازیابی در موتور تازه.
      final savedJson = driver.engine.state.toJson();
      final engine2 = HokmEngine(random: Random(556));
      engine2.restoreState(GameState.fromJson(savedJson));

      // ادامهٔ بازی روی موتور دوم.
      final driver2 = AiMatchDriver(seed: 556);
      driver2.engine.restoreState(GameState.fromJson(savedJson));
      var safety = 0;
      while (driver2.engine.state.phase == GamePhase.playing) {
        safety++;
        expect(safety, lessThan(60));
        final seat = driver2.engine.state.currentTurn;
        driver2.engine
            .playCard(seat, driver2.players[seat]!.chooseCard(driver2.engine.state));
      }
      expect(driver2.engine.state.isRoundComplete, isTrue);
    });

    test('save during trump selection can be resumed (reconstructed deal)', () {
      final driver = AiMatchDriver(seed: 808);
      driver.engine.startMatch();
      driver.engine.determineHakim();
      driver.engine.startRound(); // فاز انتخاب حکم — ۵ کارت به هر نفر.

      final json = driver.engine.state.toJson();
      final engine2 = HokmEngine(random: Random(809));
      engine2.restoreState(GameState.fromJson(json));
      expect(engine2.state.phase, GamePhase.awaitingTrumpSelection);

      // حاکم حکم را اعلام می‌کند → ۱۳ کارت برای همه.
      final hakim = engine2.state.hakim!;
      engine2.selectTrump(hakim, Suit.hearts);
      for (final p in engine2.state.players) {
        expect(p.handCount, 13);
      }
      final all = <PlayingCard>{
        for (final p in engine2.state.players) ...p.hand,
      };
      expect(all.length, 52);
    });
  });
}
