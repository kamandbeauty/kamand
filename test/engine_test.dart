import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelem/game/engine.dart';
import 'package:shelem/game/rules.dart';
import 'package:shelem/game/scoring.dart';
import 'package:shelem/model/card.dart';
import 'package:shelem/model/enums.dart';

import 'sim_helper.dart';

ShelemEngine freshEngine({GameConfig? config, int seed = 7}) {
  final ShelemEngine e = ShelemEngine(
    config: config ?? const GameConfig(targetScore: 1000000),
    random: Random(seed),
  )..startRound();
  return e;
}

void main() {
  group('پخش کارت', () {
    test('۱۲ برگ برای هر نفر و ۴ برگ گل', () {
      final ShelemEngine e = freshEngine();
      for (final List<PlayingCard> h in e.hands) {
        expect(h.length, 12);
      }
      expect(e.kitty.length, 4);
      final Set<PlayingCard> all = <PlayingCard>{
        for (final List<PlayingCard> h in e.hands) ...h,
        ...e.kitty,
      };
      expect(all.length, 52);
      expect(e.phase, GamePhase.bidding);
      expect(e.bidder, nextPlayer(e.dealer));
    });

    test('حالت جوکر: ۵۴ برگ، گلِ ۶ تایی و حداقل خواندن ۱۲۰', () {
      final ShelemEngine e = freshEngine(
        config: const GameConfig(withJokers: true, targetScore: 1000000),
      );
      expect(e.kitty.length, 6);
      expect(e.config.minBid, 120);
      expect(e.config.maxNumericBid, 200);
      expect(e.config.totalPoints, 200);
      final Set<PlayingCard> all = <PlayingCard>{
        for (final List<PlayingCard> h in e.hands) ...h,
        ...e.kitty,
      };
      expect(all.length, 54);
    });

    test('صاحب‌دست هر راند عوض می‌شود', () {
      final ShelemEngine e = freshEngine();
      final int first = e.dealer;
      e.startRound();
      expect(e.dealer, nextPlayer(first));
    });
  });

  group('مرحلهٔ خواندن', () {
    test('عددهای مجاز مضرب ۵ بین ۱۰۰ و ۱۶۵ به‌علاوهٔ شلم هستند', () {
      final ShelemEngine e = freshEngine();
      final List<int> bids = e.availableBids();
      expect(bids.first, 100);
      expect(bids.contains(165), isTrue);
      expect(bids.contains(kShelemBid), isTrue);
      expect(bids.contains(102), isFalse);
      expect(e.canBid(100), isTrue);
      expect(e.canBid(95), isFalse);
    });

    test('هر خواندن باید از قبلی بالاتر باشد', () {
      final ShelemEngine e = freshEngine();
      e.placeBid(100);
      expect(e.highBid, 100);
      expect(e.canBid(100), isFalse);
      expect(e.canBid(105), isTrue);
    });

    test('پاس دادن یعنی خروج دائمی از حراج', () {
      final ShelemEngine e = freshEngine();
      final int first = e.bidder;
      e.placeBid(100);
      e.passBid();
      e.passBid();
      expect(e.passed.where((bool p) => p).length, 2);
      e.passBid();
      expect(e.hakem, first);
      expect(e.contract, 100);
      expect(e.phase, GamePhase.kitty);
    });

    test('پاسِ همه ⇒ پخش دوباره', () {
      final ShelemEngine e = freshEngine();
      final int round = e.round;
      e.passBid();
      e.passBid();
      e.passBid();
      e.passBid();
      expect(e.phase, GamePhase.bidding);
      expect(e.round, round);
      expect(e.highBid, 0);
    });

    test('پاسِ همه با قانونِ اجبار صاحب‌دست', () {
      final ShelemEngine e = freshEngine(
        config: const GameConfig(
          forceDealerBidOnAllPass: true,
          targetScore: 1000000,
        ),
      );
      final int dealer = e.dealer;
      for (int i = 0; i < 4; i++) {
        e.passBid();
      }
      expect(e.hakem, dealer);
      expect(e.contract, 100);
      expect(e.phase, GamePhase.kitty);
    });
  });

  group('گل و کنار گذاشتن برگ', () {
    ShelemEngine withHakem() {
      final ShelemEngine e = freshEngine();
      e.placeBid(105);
      e.passBid();
      e.passBid();
      e.passBid();
      return e;
    }

    test('حاکم ۱۶ برگ می‌گیرد و ۴ برگ کنار می‌گذارد', () {
      final ShelemEngine e = withHakem();
      final int h = e.hakem!;
      e.takeKitty();
      expect(e.hands[h].length, 16);
      expect(e.phase, GamePhase.discarding);
      final List<PlayingCard> toss = e.hands[h].take(4).toList();
      e.discardCards(toss);
      expect(e.hands[h].length, 12);
      expect(e.discards, toss);
      expect(e.phase, GamePhase.declaringTrump);
      expect(e.turn, h);
    });

    test('برگ‌های کنارگذاشته به‌علاوهٔ ۵ امتیاز برای تیم حاکم', () {
      final ShelemEngine e = withHakem();
      final int h = e.hakem!;
      e.takeKitty();
      final List<PlayingCard> toss = e.hands[h].take(4).toList();
      e.discardCards(toss);
      final List<int> pts = e.currentPoints();
      expect(pts[teamOf(h)], kTrickBonus + cardPointsOf(toss));
    });

    test('تعداد اشتباهِ برگ‌های کنارگذاشته خطا می‌دهد', () {
      final ShelemEngine e = withHakem();
      e.takeKitty();
      expect(
        () => e.discardCards(e.hands[e.hakem!].take(3).toList()),
        throwsArgumentError,
      );
    });
  });

  group('اعلام حکم', () {
    ShelemEngine ready() {
      final ShelemEngine e = freshEngine();
      e.placeBid(100);
      e.passBid();
      e.passBid();
      e.passBid();
      e.takeKitty();
      e.discardCards(e.hands[e.hakem!].take(4).toList());
      return e;
    }

    test('خالِ اولین برگِ حاکم، حکم می‌شود', () {
      final ShelemEngine e = ready();
      final PlayingCard card = e.hands[e.hakem!].first;
      e.playCard(e.hakem!, card);
      expect(e.trump, card.suit);
      expect(e.phase, GamePhase.playing);
      expect(e.trick.length, 1);
    });

    test('حالت انتخاب خال از منو، اولین برگ را به حکم محدود می‌کند', () {
      final ShelemEngine e = ready();
      final int h = e.hakem!;
      final Suit pick = e.hands[h].first.suit;
      e.declareTrumpBeforeLead(pick);
      expect(e.trump, pick);
      expect(e.mustLeadTrumpFirst, isTrue);
      final List<PlayingCard> legal = e.legalFor(h);
      expect(legal.every((PlayingCard c) => isTrumpCard(c, pick)), isTrue);
      e.playCard(h, legal.first);
      expect(e.mustLeadTrumpFirst, isFalse);
    });
  });

  group('یک راند کامل با ربات‌ها', () {
    test('بدون جوکر: مجموع امتیازها دقیقاً ۱۶۵ است', () {
      final ShelemEngine e = ShelemEngine(
        config: const GameConfig(targetScore: 1000000),
        random: Random(11),
      );
      for (int i = 0; i < 12; i++) {
        playRound(e, Difficulty.hard, Random(100 + i));
        assertRoundInvariants(
          e,
          (bool ok, String msg) => expect(ok, isTrue, reason: msg),
        );
        expect(e.history.length, i + 1);
      }
    });

    test('با جوکر: مجموع امتیازها دقیقاً ۲۰۰ است', () {
      final ShelemEngine e = ShelemEngine(
        config: const GameConfig(withJokers: true, targetScore: 1000000),
        random: Random(3),
      );
      for (int i = 0; i < 8; i++) {
        playRound(e, Difficulty.normal, Random(200 + i));
        assertRoundInvariants(
          e,
          (bool ok, String msg) => expect(ok, isTrue, reason: msg),
        );
      }
    });

    test('بازی تا رسیدن به امتیاز هدف ادامه پیدا می‌کند', () {
      final ShelemEngine e = ShelemEngine(
        config: const GameConfig(targetScore: 660),
        random: Random(5),
      );
      int guard = 0;
      while (e.phase != GamePhase.gameOver && guard < 60) {
        playRound(e, Difficulty.normal, Random(300 + guard));
        guard++;
      }
      expect(e.phase, GamePhase.gameOver);
      expect(e.winnerTeam, isNotNull);
      expect(e.scores[e.winnerTeam!] >= 660, isTrue);
    });
  });

  group('ذخیره و بازیابی', () {
    test('وضعیت میانهٔ بازی بدون تغییر بازیابی می‌شود', () {
      final ShelemEngine e = freshEngine(seed: 21);
      final Random r = Random(4);
      for (int i = 0; i < 40; i++) {
        if (e.phase == GamePhase.roundComplete ||
            e.phase == GamePhase.gameOver) {
          break;
        }
        botStep(e, Difficulty.normal, r);
      }
      final ShelemEngine back = ShelemEngine.fromJson(e.toJson());
      expect(back.phase, e.phase);
      expect(back.turn, e.turn);
      expect(back.trump, e.trump);
      expect(back.contract, e.contract);
      expect(back.hakem, e.hakem);
      expect(back.scores, e.scores);
      expect(back.hands[0], e.hands[0]);
      expect(back.hands[2], e.hands[2]);
      expect(back.discards, e.discards);
      expect(back.completedTricks.length, e.completedTricks.length);
      expect(back.currentPoints(), e.currentPoints());
    });

    test('راندِ تمام‌شده هم بازیابی می‌شود', () {
      final ShelemEngine e = ShelemEngine(
        config: const GameConfig(targetScore: 1000000),
        random: Random(9),
      );
      playRound(e, Difficulty.master, Random(77));
      final ShelemEngine back = ShelemEngine.fromJson(e.toJson());
      expect(back.outcome?.hakemDelta, e.outcome?.hakemDelta);
      expect(back.history.length, e.history.length);
      expect(back.scores, e.scores);
    });
  });
}
