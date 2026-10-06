import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelem/ai/bot.dart';
import 'package:shelem/game/engine.dart';
import 'package:shelem/game/rules.dart';
import 'package:shelem/model/card.dart';
import 'package:shelem/model/enums.dart';

import 'sim_helper.dart';

PlayingCard c(Suit s, int r) => PlayingCard(s, r);

void main() {
  group('ارزیابی دست', () {
    test('دستِ قوی تخمینِ بالاتری می‌گیرد', () {
      final List<PlayingCard> strong = <PlayingCard>[
        c(Suit.spades, 14), c(Suit.spades, 13), c(Suit.spades, 12),
        c(Suit.spades, 11), c(Suit.spades, 10), c(Suit.spades, 9),
        c(Suit.hearts, 14), c(Suit.hearts, 10), c(Suit.clubs, 14),
        c(Suit.clubs, 5), c(Suit.diamonds, 14), c(Suit.diamonds, 10),
      ];
      final List<PlayingCard> weak = <PlayingCard>[
        c(Suit.spades, 2), c(Suit.spades, 3), c(Suit.hearts, 4),
        c(Suit.hearts, 6), c(Suit.clubs, 7), c(Suit.clubs, 8),
        c(Suit.diamonds, 2), c(Suit.diamonds, 3), c(Suit.diamonds, 6),
        c(Suit.hearts, 7), c(Suit.clubs, 9), c(Suit.spades, 4),
      ];
      final double a = ShelemBot.estimatePoints(strong, withKitty: true);
      final double b = ShelemBot.estimatePoints(weak, withKitty: true);
      expect(a > b, isTrue, reason: 'دستِ قوی باید تخمین بالاتری بگیرد');
      expect(a > 120, isTrue, reason: 'تخمین دستِ قوی کم است: $a');
      expect(b < 100, isTrue, reason: 'تخمین دستِ ضعیف زیاد است: $b');
      expect(ShelemBot.bestTrump(strong), Suit.spades);
      expect(ShelemBot.expectedTricks(strong, Suit.spades) > 6, isTrue);
    });

    test('ربات با دستِ ضعیف پاس می‌دهد', () {
      final ShelemEngine e = ShelemEngine(random: Random(1))..startRound();
      e.hands[e.bidder] = <PlayingCard>[
        c(Suit.spades, 2), c(Suit.spades, 3), c(Suit.hearts, 4),
        c(Suit.hearts, 6), c(Suit.clubs, 7), c(Suit.clubs, 8),
        c(Suit.diamonds, 2), c(Suit.diamonds, 3), c(Suit.diamonds, 6),
        c(Suit.hearts, 7), c(Suit.clubs, 9), c(Suit.spades, 4),
      ];
      expect(
        ShelemBot.chooseBid(e, e.bidder, Difficulty.master, rng: Random(2)),
        isNull,
      );
    });
  });

  group('کنار گذاشتن برگ‌های گل', () {
    test('دقیقاً به تعداد خواسته‌شده و بدون حکم‌های بالا', () {
      final List<PlayingCard> hand = <PlayingCard>[
        c(Suit.spades, 14), c(Suit.spades, 13), c(Suit.spades, 12),
        c(Suit.spades, 11), c(Suit.spades, 2), c(Suit.hearts, 3),
        c(Suit.hearts, 4), c(Suit.clubs, 2), c(Suit.clubs, 3),
        c(Suit.clubs, 4), c(Suit.diamonds, 2), c(Suit.diamonds, 3),
        c(Suit.diamonds, 4), c(Suit.diamonds, 7), c(Suit.hearts, 9),
        c(Suit.clubs, 8),
      ];
      final List<PlayingCard> out =
          ShelemBot.chooseDiscards(hand, 4, Suit.spades);
      expect(out.length, 4);
      expect(out.toSet().length, 4);
      expect(out.every(hand.contains), isTrue);
      expect(
        out.any((PlayingCard x) => x.suit == Suit.spades),
        isFalse,
        reason: 'ربات نباید حکم کنار بگذارد: $out',
      );
    });

    test('۵ و ۱۰ بی‌پشتوانه کنار گذاشته می‌شوند (بانک کردن امتیاز)', () {
      final List<PlayingCard> hand = <PlayingCard>[
        c(Suit.spades, 14), c(Suit.spades, 13), c(Suit.spades, 12),
        c(Suit.spades, 11), c(Suit.spades, 10), c(Suit.spades, 9),
        c(Suit.hearts, 5), c(Suit.hearts, 6), c(Suit.hearts, 7),
        c(Suit.clubs, 10), c(Suit.clubs, 6), c(Suit.clubs, 7),
        c(Suit.diamonds, 5), c(Suit.diamonds, 6), c(Suit.diamonds, 7),
        c(Suit.diamonds, 8),
      ];
      final List<PlayingCard> out =
          ShelemBot.chooseDiscards(hand, 4, Suit.spades);
      final int pts = cardPointsOf(out);
      expect(pts >= 15, isTrue, reason: 'امتیاز برگ‌های کنارگذاشته: $pts');
    });
  });

  group('انتخاب کارت', () {
    test('ربات همیشه کارتِ مجاز بازی می‌کند', () {
      for (final Difficulty d in Difficulty.values) {
        final ShelemEngine e = ShelemEngine(
          config: const GameConfig(targetScore: 1000000),
          random: Random(d.index + 1),
        )..startRound();
        final Random r = Random(d.index + 50);
        int guard = 0;
        while (e.phase != GamePhase.roundComplete && guard < 3000) {
          if (e.phase == GamePhase.playing) {
            final PlayingCard card = ShelemBot.chooseCard(e, e.turn, d, rng: r);
            expect(
              e.legalFor(e.turn).contains(card),
              isTrue,
              reason: 'کارتِ غیرمجاز در سطح ${d.name}',
            );
          }
          botStep(e, d, r);
          guard++;
        }
        expect(e.phase, GamePhase.roundComplete);
      }
    });

    test('آخرین نفر با برگِ برنده، دستِ پرامتیاز را می‌گیرد', () {
      final ShelemEngine e = ShelemEngine(random: Random(8))..startRound();
      e
        ..hakem = 0
        ..contract = 100
        ..trump = Suit.clubs
        ..phase = GamePhase.playing
        ..leader = 0
        ..turn = 3
        ..trick = <PlayedCard>[
          PlayedCard(0, c(Suit.hearts, 3)),
          PlayedCard(1, c(Suit.hearts, 14)),
          PlayedCard(2, c(Suit.hearts, 10)),
        ];
      e.hands[3] = <PlayingCard>[c(Suit.hearts, 2), c(Suit.hearts, 5)];
      final PlayingCard card =
          ShelemBot.chooseCard(e, 3, Difficulty.master, rng: Random(1));
      // بازیکن ۳ با بازیکن ۱ هم‌تیم است؛ باید امتیاز را به یارش بدهد
      expect(card, c(Suit.hearts, 5));
    });

    test('حریفِ آخر با برگِ برنده، دستِ پرامتیاز را می‌بُرد', () {
      final ShelemEngine e = ShelemEngine(random: Random(8))..startRound();
      e
        ..hakem = 0
        ..contract = 100
        ..trump = Suit.clubs
        ..phase = GamePhase.playing
        ..leader = 0
        ..turn = 1
        ..trick = <PlayedCard>[
          PlayedCard(2, c(Suit.hearts, 3)),
          PlayedCard(3, c(Suit.hearts, 5)),
          PlayedCard(0, c(Suit.hearts, 14)),
        ];
      e.hands[1] = <PlayingCard>[c(Suit.diamonds, 2), c(Suit.clubs, 4)];
      final PlayingCard card =
          ShelemBot.chooseCard(e, 1, Difficulty.master, rng: Random(1));
      expect(card, c(Suit.clubs, 4), reason: 'باید با حکم می‌بُرید');
    });
  });

  group('کالیبراسیون هوش مصنوعی', () {
    test('نرخ موفقیتِ قرارداد در بازی ربات‌ها منطقی است', () {
      const int rounds = 200;
      final ShelemEngine e = ShelemEngine(
        config: const GameConfig(targetScore: 100000000),
        random: Random(2024),
      );
      int made = 0;
      int yasa = 0;
      int slams = 0;
      double estimateSum = 0;
      double actualSum = 0;
      final Map<int, int> contracts = <int, int>{};
      for (int i = 0; i < rounds; i++) {
        final Random r = Random(1000 + i);
        e.startRound();
        double estimate = 0;
        int guard = 0;
        while (e.phase != GamePhase.roundComplete &&
            e.phase != GamePhase.gameOver &&
            guard < 5000) {
          if (e.phase == GamePhase.kitty && estimate == 0) {
            estimate = ShelemBot.estimatePoints(
              e.hands[e.hakem!],
              withKitty: true,
            );
          }
          botStep(e, Difficulty.hard, r);
          guard++;
        }
        final RoundRecord last = e.history.last;
        contracts[last.outcome.contract] =
            (contracts[last.outcome.contract] ?? 0) + 1;
        estimateSum += estimate;
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
      print('کالیبراسیون ($rounds راند): موفقیت قرارداد = '
          '${(rate * 100).toStringAsFixed(1)}٪ | یاسا = $yasa | شلم = $slams');
      // ignore: avoid_print
      print('میانگین قرارداد = ${avgContract.toStringAsFixed(1)} | '
          'میانگین تخمین حاکم = ${(estimateSum / rounds).toStringAsFixed(1)} | '
          'میانگین امتیاز واقعی حاکم = '
          '${(actualSum / rounds).toStringAsFixed(1)}');
      // ignore: avoid_print
      print('توزیع قراردادها: $contracts');
      expect(
        rate > 0.40 && rate < 0.92,
        isTrue,
        reason: 'نرخ موفقیتِ قرارداد غیرمنطقی است: $rate',
      );
      expect(
        avgContract >= 105 && avgContract <= 150,
        isTrue,
        reason: 'میانگینِ قرارداد غیرمنطقی است: $avgContract',
      );
    });

    test('سطح استاد از سطح آسان قوی‌تر بازی می‌کند', () {
      // تیم ۰ = استاد، تیم ۱ = آسان؛ هر دو با یک دستِ یکسان شروع می‌کنند.
      int masterPoints = 0;
      int easyPoints = 0;
      for (int i = 0; i < 24; i++) {
        final ShelemEngine e = ShelemEngine(
          config: const GameConfig(targetScore: 100000000),
          random: Random(500 + i),
        )..startRound();
        final Random r = Random(900 + i);
        int guard = 0;
        while (e.phase != GamePhase.roundComplete && guard < 3000) {
          if (e.phase == GamePhase.playing) {
            final Difficulty d =
                teamOf(e.turn) == 0 ? Difficulty.master : Difficulty.easy;
            e.playCard(e.turn, ShelemBot.chooseCard(e, e.turn, d, rng: r));
          } else {
            botStep(e, Difficulty.normal, r);
          }
          guard++;
        }
        final List<int> pts = e.currentPoints();
        masterPoints += pts[0];
        easyPoints += pts[1];
      }
      // ignore: avoid_print
      print('استاد $masterPoints در برابر آسان $easyPoints');
      expect(
        masterPoints > easyPoints,
        isTrue,
        reason: 'سطح استاد باید در مجموع امتیاز بیشتری بگیرد',
      );
    });
  });
}
