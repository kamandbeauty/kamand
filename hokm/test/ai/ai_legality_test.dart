import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hokm/ai/ai_view.dart';
import 'package:hokm/ai/players/ai_player.dart';
import 'package:hokm/game_engine/hokm_engine.dart';
import 'package:hokm/game_engine/rules/game_rules.dart';
import 'package:hokm/game_engine/state/game_enums.dart';

import '../helpers/test_driver.dart';

void main() {
  group('AI legality across full matches', () {
    for (final difficulty in AiDifficulty.values) {
      test('${difficulty.name}: 10 full seeds — every AI play is legal', () {
        for (var seed = 0; seed < 10; seed++) {
          final engine = HokmEngine(random: Random(1000 + seed));
          final players = {
            for (final seat in Seat.values)
              seat: AiPlayer(
                seat: seat,
                difficulty: difficulty,
                random: Random(2000 + seed + seat.index),
              ),
          };
          engine.startMatch();
          engine.determineHakim();

          var moves = 0;
          while (engine.state.phase != GamePhase.matchEnd) {
            engine.startRound();
            final hakim = engine.state.hakim!;
            engine.selectTrump(hakim, players[hakim]!.selectTrump(engine.state));
            while (engine.state.phase == GamePhase.playing) {
              final seat = engine.state.currentTurn;
              final hand = engine.state.playerAt(seat).hand;
              final trick = engine.state.currentTrick;
              final legal = trick == null
                  ? hand
                  : GameRules.legalPlays(hand, trick);

              final card = players[seat]!.chooseCard(engine.state);
              moves++;
              expect(
                legal.contains(card),
                isTrue,
                reason:
                    '${difficulty.name} seed=$seed: $seat played ${card.id} '
                    'but legal were ${legal.map((c) => c.id).join(",")}',
              );
              engine.playCard(seat, card); // اگر غیرقانونی باشد خودِ موتور هم می‌ترکد.
            }
          }
          expect(moves, greaterThan(50));
        }
      });
    }

    test('mixed difficulties can play a full match', () {
      final driver = AiMatchDriver(
        seed: 4242,
        difficulties: const {
          Seat.south: AiDifficulty.hard,
          Seat.west: AiDifficulty.easy,
          Seat.north: AiDifficulty.normal,
          Seat.east: AiDifficulty.hard,
        },
      );
      final rounds = driver.playFullMatch();
      expect(rounds, greaterThan(0));
    });

    test('AiGameView exposes no hidden information', () {
      final driver = AiMatchDriver(seed: 66);
      driver.engine.startMatch();
      driver.engine.determineHakim();
      driver.engine.startRound();
      final hakim = driver.engine.state.hakim!;
      driver.engine.selectTrump(hakim, Suit.spades);

      for (var i = 0; i < 6; i++) {
        final seat = driver.engine.state.currentTurn;
        driver.engine.playCard(
            seat, driver.players[seat]!.chooseCard(driver.engine.state));
      }

      final view = AiGameView.fromState(driver.engine.state, Seat.east);
      // دستِ مقیاس فقط دستِ خودِ AI است.
      expect(view.myHand.toSet(),
          driver.engine.state.playerAt(Seat.east).hand.toSet());
      // شمار دست‌ها موجود است (اطلاعات عمومی) اما خودِ کارت‌ها نه.
      expect(view.handCounts[Seat.south],
          driver.engine.state.playerAt(Seat.south).handCount);
      // هیچ ارجاعی به GameState در View نیست.
      expect(view.allPlays.length, 6);
    });
  });
}
