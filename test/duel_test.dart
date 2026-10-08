/// تست‌های بازیِ دو نفره (نفر به نفر).
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelem/ai/bot.dart';
import 'package:shelem/game/engine.dart';
import 'package:shelem/model/card.dart';
import 'package:shelem/model/enums.dart';

import 'sim_helper.dart';

const GameConfig _duel = GameConfig(players: 2, targetScore: 1000000);
const GameConfig _duelJoker = GameConfig(
  players: 2,
  withJokers: true,
  targetScore: 1000000,
);

void main() {
  group('تنظیماتِ دو نفره', () {
    test('اعداد پایه درست‌اند', () {
      expect(_duel.players, 2);
      expect(_duel.handSize, 12);
      expect(_duel.kittySize, 4);
      expect(_duel.stockSize, 24);
      expect(_duel.totalTricks, 24);
      expect(_duel.totalPoints, 225);
      expect(_duel.minBid, 135);
      expect(_duel.maxNumericBid, 225);
      expect(_duel.isDuel, isTrue);

      expect(_duelJoker.stockSize, 24);
      expect(_duelJoker.totalTricks, 24);
      expect(_duelJoker.totalPoints, 260);
      expect(_duelJoker.minBid, 155);
    });

    test('چهار نفره دست‌نخورده مانده است', () {
      const GameConfig four = GameConfig();
      expect(four.stockSize, 0);
      expect(four.totalTricks, 12);
      expect(four.totalPoints, 165);
      expect(four.minBid, 100);
      expect(four.maxNumericBid, 165);
      const GameConfig fourJoker = GameConfig(withJokers: true);
      expect(fourJoker.totalPoints, 200);
      expect(fourJoker.minBid, 120);
      expect(fourJoker.totalTricks, 12);
    });
  });

  group('پخش کارت دو نفره', () {
    test('۱۲ برگ برای هر نفر، ۴ برگ گل و ۲۴ برگ روی هم', () {
      final ShelemEngine e = ShelemEngine(config: _duel, random: Random(5))
        ..startRound();
      expect(e.hands.length, 2);
      expect(e.hands[0].length, 12);
      expect(e.hands[1].length, 12);
      expect(e.kitty.length, 4);
      expect(e.stock.length, 24);
      final Set<PlayingCard> all = <PlayingCard>{
        ...e.hands[0],
        ...e.hands[1],
        ...e.kitty,
        ...e.stock,
      };
      expect(all.length, 52);
      expect(e.bids.length, 2);
      expect(e.passed.length, 2);
      expect(e.phase, GamePhase.bidding);
      expect(e.bidder, e.nextSeat(e.dealer));
    });

    test('نوبت بین دو نفر می‌چرخد', () {
      final ShelemEngine e = ShelemEngine(config: _duel, random: Random(5));
      expect(e.nextSeat(0), 1);
      expect(e.nextSeat(1), 0);
      expect(teamOf(0), 0);
      expect(teamOf(1), 1);
    });
  });

  group('کشیدن برگ از روی هم', () {
    test('بعد از هر دست هر نفر یک برگ می‌کشد و در پایان ۲۴ دست بازی می‌شود',
        () {
      final Random r = Random(9);
      final ShelemEngine e = ShelemEngine(config: _duel, random: r);
      e.startRound();
      // حراج
      while (e.phase == GamePhase.bidding) {
        final int? bid = ShelemBot.chooseBid(e, e.bidder, Difficulty.hard,
            rng: r);
        if (bid == null && e.canPass) {
          e.passBid();
        } else {
          e.placeBid(bid ?? e.availableBids().first);
        }
      }
      expect(e.phase, GamePhase.kitty);
      e.takeKitty();
      expect(e.hands[e.hakem!].length, 16);
      e.discardCards(e.hands[e.hakem!].take(4).toList());
      expect(e.hands[e.hakem!].length, 12);

      int tricks = 0;
      while (e.phase != GamePhase.roundComplete &&
          e.phase != GamePhase.gameOver) {
        if (e.phase == GamePhase.trickComplete) {
          final int before = e.stock.length;
          e.collectTrick();
          tricks++;
          if (before >= 2) {
            expect(e.hands[0].length, 12);
            expect(e.hands[1].length, 12);
            expect(e.stock.length, before - 2);
          }
        } else {
          botStep(e, Difficulty.hard, r);
        }
      }
      expect(tricks, 24);
      expect(e.stock, isEmpty);
      expect(e.tricksWon[0] + e.tricksWon[1], 24);
      expect(e.currentPoints()[0] + e.currentPoints()[1], 225);
    });
  });

  group('کالیبراسیون دو نفره', () {
    test('نرخ موفقیتِ قرارداد و توزیعِ خواندن منطقی است', () {
      const int rounds = 150;
      final ShelemEngine e = ShelemEngine(
        config: const GameConfig(players: 2, targetScore: 100000000),
        random: Random(2025),
      );
      int made = 0;
      int yasa = 0;
      int slams = 0;
      double actualSum = 0;
      final Map<int, int> contracts = <int, int>{};
      for (int i = 0; i < rounds; i++) {
        final Random r = Random(3000 + i);
        playRound(e, Difficulty.hard, r);
        final RoundRecord last = e.history.last;
        contracts[last.outcome.contract] =
            (contracts[last.outcome.contract] ?? 0) + 1;
        actualSum += last.outcome.hakemPoints;
        if (last.outcome.contractMade) made++;
        if (last.outcome.yasa) yasa++;
        if (last.outcome.slam) slams++;
      }
      final double rate = made / rounds;
      final double avgContract = contracts.entries
              .map((MapEntry<int, int> x) => x.key * x.value)
              .fold<int>(0, (int a, int b) => a + b) /
          rounds;
      // ignore: avoid_print
      print('کالیبراسیون دو نفره ($rounds راند): موفقیت = '
          '${(rate * 100).toStringAsFixed(1)}٪ | یاسا = $yasa | شلم = $slams');
      // ignore: avoid_print
      print('میانگین قرارداد = ${avgContract.toStringAsFixed(1)} | '
          'میانگین امتیاز حاکم = ${(actualSum / rounds).toStringAsFixed(1)}');
      // ignore: avoid_print
      print('توزیع قراردادها: $contracts');
      expect(rate > 0.35 && rate < 0.95, isTrue,
          reason: 'نرخ موفقیت غیرمنطقی: $rate');
      expect(avgContract >= 135, isTrue);
    });
  });

  group('شبیه‌سازی دو نفره', () {
    test('۸۰ راندِ کامل بدون خطا و با امتیازِ درست', () {
      for (int seed = 0; seed < 80; seed++) {
        final bool jokers = seed.isOdd;
        final ShelemEngine e = ShelemEngine(
          config: jokers ? _duelJoker : _duel,
          random: Random(seed),
        );
        playRound(e, Difficulty.values[seed % 4], Random(seed + 77));
        final List<int> pts = e.currentPoints();
        expect(
          pts[0] + pts[1],
          e.config.totalPoints,
          reason: 'seed $seed',
        );
        expect(e.tricksWon[0] + e.tricksWon[1], 24, reason: 'seed $seed');
        expect(e.hands.every((List<PlayingCard> h) => h.isEmpty), isTrue);
        expect(e.stock, isEmpty);
        expect(e.outcome, isNotNull);
      }
    });

    test('ذخیره و بازیابیِ بازیِ دو نفره', () {
      final Random r = Random(21);
      final ShelemEngine e = ShelemEngine(config: _duel, random: r);
      e.startRound();
      int guard = 0;
      while (e.phase != GamePhase.roundComplete && guard < 4000) {
        final String raw = jsonEncode(e.toJson());
        final ShelemEngine copy = ShelemEngine.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        expect(copy.config.players, 2);
        expect(jsonEncode(copy.toJson()), raw, reason: 'فاز ${e.phase}');
        botStep(e, Difficulty.hard, r);
        guard++;
      }
      expect(e.phase, GamePhase.roundComplete);
    });

    test('یک بازیِ دو نفرهٔ کامل تا امتیاز هدف تمام می‌شود', () {
      final Random r = Random(4);
      final ShelemEngine e = ShelemEngine(
        config: const GameConfig(players: 2, targetScore: 660),
        random: r,
      );
      int rounds = 0;
      while (e.phase != GamePhase.gameOver && rounds < 60) {
        playRound(e, Difficulty.hard, r);
        if (e.phase == GamePhase.roundComplete) rounds++;
      }
      expect(e.phase, GamePhase.gameOver);
      expect(e.winnerTeam, isNotNull);
    });
  });
}
