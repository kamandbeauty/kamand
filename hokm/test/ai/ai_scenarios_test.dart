import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hokm/ai/ai_view.dart';
import 'package:hokm/ai/memory/memory_tracker.dart';
import 'package:hokm/ai/strategy/hukum_selector.dart';
import 'package:hokm/ai/strategy/strategy_engine.dart';
import 'package:hokm/game_engine/models/playing_card.dart';
import 'package:hokm/game_engine/models/rank.dart';
import 'package:hokm/game_engine/models/suit.dart';
import 'package:hokm/game_engine/models/trick.dart';
import 'package:hokm/game_engine/rules/game_rules.dart';
import 'package:hokm/game_engine/state/game_enums.dart';

PlayingCard c(String id) => PlayingCard.fromId(id);

Trick trick(List<String> plays) {
  final leader = plays.isEmpty
      ? Seat.south
      : Seat.fromIndex(int.parse(plays.first.split(':').first));
  final trick = Trick(leaderSeat: leader);
  for (final p in plays) {
    final kv = p.split(':');
    trick.add(
        PlayedCard(seat: Seat.fromIndex(int.parse(kv[0])), card: c(kv[1])));
  }
  return trick;
}

void main() {
  const trump = Suit.spades;

  group('Scenario: follow suit (spec §31)', () {
    for (final difficulty in AiDifficulty.values) {
      test('${difficulty.name}: never breaks suit when holding it', () {
        final strategy = StrategyEngine(
            difficulty: difficulty, random: Random(1));
        for (var trial = 0; trial < 30; trial++) {
          // دستی با ۳ خشت + کارت‌های دیگر؛ زمینه خشت است.
          final hand = [c('D_2'), c('D_7'), c('D_K'), c('S_A'), c('H_Q')];
          final current = trick(['0:D_9']);
          final view = AiGameView.testing(
            mySeat: Seat.east,
            myHand: hand,
            trump: trump,
            currentTrick: current,
          );
          final legal = GameRules.legalPlays(hand, current);
          final chosen = strategy.chooseCard(view, legal);
          expect(chosen.suit, Suit.diamonds,
              reason: '${difficulty.name} must follow diamonds');
        }
      });
    }

    test('void in led suit: may play trump (and should cut when beaten)', () {
      final strategy =
          StrategyEngine(difficulty: AiDifficulty.normal, random: Random(2));
      // خشت نداریم؛ زمینه خشت و حریف (غرب) با K خشت جلو است.
      final hand = [c('S_3'), c('S_9'), c('H_8')];
      final current = trick(['1:D_K']); // غرب (حریف شمال) آغازگر و جلو است.
      final view = AiGameView.testing(
        mySeat: Seat.north, // یارِ آغازگر نیست → حریف جلو است
        myHand: hand,
        trump: trump,
        currentTrick: current,
      );
      final legal = GameRules.legalPlays(hand, current);
      expect(legal.length, 3, reason: 'No diamonds → free choice');
      final chosen = strategy.chooseCard(view, legal);
      expect(chosen.suit, Suit.spades,
          reason: 'Normal AI should cut with its cheapest trump (S_3)');
      expect(chosen, c('S_3'));
    });

    test('partner is winning: dump lowest junk, never waste power', () {
      final strategy =
          StrategyEngine(difficulty: AiDifficulty.normal, random: Random(3));
      // من شمال‌ام؛ یارم جنوب با آس گشنیز آغاز کرده (زمینه گشنیز) و جلو است.
      final current = trick(['0:C_A', '1:C_5', '3:C_6']);
      final hand = [c('S_A'), c('H_4'), c('H_8'), c('D_10')]; // بدون گشنیز
      final view = AiGameView.testing(
        mySeat: Seat.north,
        myHand: hand,
        trump: trump,
        currentTrick: current,
      );
      final legal = GameRules.legalPlays(hand, current);
      expect(legal.length, 4, reason: 'Void in clubs → free choice');
      final chosen = strategy.chooseCard(view, legal);
      expect(chosen, c('H_4'),
          reason: 'Partner winning the trick → dump the cheapest junk card');
    });
  });

  group('Scenario: cheap win (Normal/Hard)', () {
    test('beats current best with the smallest sufficient card', () {
      final strategy =
          StrategyEngine(difficulty: AiDifficulty.hard, random: Random(4));
      final hand = [c('H_8'), c('H_J'), c('H_A'), c('S_2')];
      final current = trick(['0:H_Q', '1:H_2', '2:H_5']); // حریف با Q جلو
      // من: شرق → حریفِ من غرب است (آغازگر). شمال یارم است (۲ و ۵ ریخته).
      final view = AiGameView.testing(
        mySeat: Seat.east,
        myHand: hand,
        trump: trump,
        currentTrick: current,
      );
      final chosen = strategy.chooseCard(
          view, GameRules.legalPlays(hand, current));
      expect(chosen, c('H_A'),
          reason: 'Only the ace beats the queen here; J and 8 lose');
    });

    test('does not waste a big card when the trick is already lost', () {
      final strategy =
          StrategyEngine(difficulty: AiDifficulty.hard, random: Random(5));
      final hand = [c('H_7'), c('H_K'), c('C_9')];
      // جنوب (یار) با ۹ دل آغاز کرده؛ غرب (حریف) با حکمِ ۳ برش داده و جلو است.
      final current = trick(['0:H_9', '1:S_3']);
      // من شمال‌ام؛ باید به دل بروم اما شاهِ من به حکم نمی‌رسد.
      final view = AiGameView.testing(
        mySeat: Seat.north,
        myHand: hand,
        trump: trump,
        currentTrick: current,
      );
      final chosen = strategy.chooseCard(
          view, GameRules.legalPlays(hand, current));
      expect(chosen, c('H_7'),
          reason: 'Cannot beat a trump with the king → save K, dump 7');
    });
  });

  group('Scenario: leading strategy (Hard)', () {
    test('close-out mode cashes a certain winner', () {
      final strategy =
          StrategyEngine(difficulty: AiDifficulty.hard, random: Random(6));
      final hand = [c('H_A'), c('D_5'), c('C_6'), c('S_9')];
      final view = AiGameView.testing(
        mySeat: Seat.west,
        myHand: hand,
        trump: trump,
        currentTrick: trick(const []),
        tricksWonUs: 6, // با یک دور دیگر دست را می‌بریم
      );
      final chosen = strategy.chooseCard(view, List.of(hand));
      expect(chosen, c('H_A'),
          reason:
              'Ace of hearts is the highest remaining hearts card → cash it');
    });
  });

  group('Hukum selection (spec §15)', () {
    const selector = HukumSelector();

    test('never random: same hand → same trump for every difficulty', () {
      final preview = [c('H_A'), c('H_K'), c('H_7'), c('S_Q'), c('C_2')];
      for (final d in AiDifficulty.values) {
        expect(selector.select(preview, d), Suit.hearts);
        expect(selector.select(preview, d), selector.select(preview, d));
      }
    });

    test('picks the strongest combined suit, not merely the longest', () {
      // پیک ۲ تاییِ ضعیف، دل ۲ تایی با A/K → باید دل انتخاب شود.
      final preview = [c('S_8'), c('S_6'), c('H_A'), c('H_K'), c('C_3')];
      expect(selector.select(preview, AiDifficulty.hard), Suit.hearts);
    });

    test('long suit with figures wins', () {
      final preview = [c('C_Q'), c('C_J'), c('C_10'), c('H_A'), c('D_2')];
      expect(selector.select(preview, AiDifficulty.hard), Suit.clubs);
    });
  });

  group('MemoryTracker (spec §10)', () {
    test('tracks played cards and computes remaining', () {
      final history = [
        trick(['0:H_A', '1:H_K', '2:H_2', '3:H_5']),
      ];
      final view = AiGameView.testing(
        mySeat: Seat.south,
        myHand: [c('H_7'), c('S_3')],
        trump: trump,
        currentTrick: trick(const []),
        trickHistory: history,
      );
      final memory = MemoryTracker.fromView(view);
      final remainingHearts = memory.remainingOfSuit(Suit.hearts);
      expect(remainingHearts.contains(c('H_A')), isFalse);
      expect(remainingHearts.contains(c('H_K')), isFalse);
      expect(remainingHearts.contains(c('H_7')), isFalse,
          reason: 'H_7 is in my own hand — not outstanding');
      expect(remainingHearts.contains(c('H_Q')), isTrue);
      expect(remainingHearts.first, c('H_Q'),
          reason: 'Queen is the highest unseen heart outside my hand');
    });

    test('detects provable voids from public play', () {
      final history = [
        // غرب به دل رفت (خال زمینه دل نبود؟ بله زمینه دل) — پس غرب دل داشت.
        // شرق حکم زد → شرق یقیناً دل ندارد.
        trick(['0:H_A', '1:S_2', '2:H_K', '3:H_5']),
      ];
      final view = AiGameView.testing(
        mySeat: Seat.south,
        myHand: const [],
        trump: trump,
        trickHistory: history,
      );
      final memory = MemoryTracker.fromView(view);
      expect(memory.isVoid(Seat.west, Suit.hearts), isTrue);
      expect(memory.isVoid(Seat.north, Suit.hearts), isFalse);
      expect(memory.isVoid(Seat.east, Suit.hearts), isFalse);
    });

    test('isHighestRemaining accounts for played and own cards', () {
      final history = [trick(['0:H_A', '1:H_2', '2:H_3', '3:H_4'])];
      final view = AiGameView.testing(
        mySeat: Seat.south,
        myHand: [c('H_K')],
        trump: trump,
        trickHistory: history,
      );
      final memory = MemoryTracker.fromView(view);
      expect(memory.isHighestRemaining(c('H_K')), isTrue,
          reason: 'Ace is played → my king is the highest hearts remaining');

      // اگر شاه را نداشتم، ملکه بالاترین نیست چون شاه هنوز بیرون است.
      final view2 = AiGameView.testing(
        mySeat: Seat.south,
        myHand: const [],
        trump: trump,
        trickHistory: history,
      );
      final memory2 = MemoryTracker.fromView(view2);
      expect(memory2.isHighestRemaining(c('H_Q')), isFalse,
          reason: 'King of hearts is still outstanding');
      expect(memory2.highestOutstanding(Suit.hearts), c('H_K'));
    });
  });
}
