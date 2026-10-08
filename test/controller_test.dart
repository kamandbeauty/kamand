/// تست‌های کنترلر: همان مسیری که رابط کاربری طی می‌کند (با زمان‌بندیِ ربات‌ها).
library;

import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelem/ai/bot.dart';
import 'package:shelem/game/engine.dart';
import 'package:shelem/model/card.dart';
import 'package:shelem/model/enums.dart';
import 'package:shelem/state/game_controller.dart';
import 'package:shelem/state/settings.dart';

/// بازیکنِ انسان را هم خودکار بازی می‌کند تا راند کامل جلو برود.
void _playFullRound(
  FakeAsync async,
  GameController c,
  Random r, {
  int maxSteps = 4000,
}) {
  final ShelemEngine e = c.engine!;
  int steps = 0;
  while (e.phase != GamePhase.roundComplete &&
      e.phase != GamePhase.gameOver &&
      steps < maxSteps) {
    switch (e.phase) {
      case GamePhase.bidding:
        if (e.bidder == 0) {
          final int? bid = ShelemBot.chooseBid(e, 0, Difficulty.hard, rng: r);
          if (bid == null && e.canPass) {
            c.humanPass();
          } else {
            c.humanBid(bid ?? e.availableBids().first);
          }
        }
      case GamePhase.kitty:
        if (e.hakem == 0) c.humanTakeKitty();
      case GamePhase.discarding:
        if (e.hakem == 0) {
          for (final PlayingCard card in ShelemBot.chooseDiscards(
            e.hands[0],
            e.config.kittySize,
            ShelemBot.bestTrump(e.hands[0]),
          )) {
            c.toggleDiscard(card);
          }
          c.confirmDiscards();
        }
      case GamePhase.declaringTrump:
      case GamePhase.playing:
        if (e.turn == 0) {
          if (e.awaitingJokerTrump) {
            c.humanDeclareTrump(ShelemBot.bestTrump(e.hands[0]));
          } else {
            c.humanPlay(ShelemBot.chooseCard(e, 0, Difficulty.hard, rng: r));
          }
        }
      case GamePhase.dealing:
      case GamePhase.trickComplete:
      case GamePhase.roundComplete:
      case GamePhase.gameOver:
        break;
    }
    // زمان را جلو می‌بریم تا تایمرهای ربات اجرا شوند.
    async.elapse(const Duration(milliseconds: 400));
    steps++;
  }
  expect(steps, lessThan(maxSteps), reason: 'بازی در فاز ${e.phase} گیر کرد');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final int players in <int>[4, 2]) {
    group('کنترلر با $players بازیکن', () {
      test('سه راندِ کامل بدون خطا و با امتیازِ درست', () {
        fakeAsync((FakeAsync async) {
          final AppSettings s = AppSettings()..speed = GameSpeed.fast;
          s.rules = s.rulesWith(players: players, targetScore: 1000000);
          final GameController c =
              GameController(settings: s, random: Random(players))..newGame();
          final Random r = Random(players * 13);

          for (int round = 1; round <= 3; round++) {
            _playFullRound(async, c, r);
            final ShelemEngine e = c.engine!;
            expect(e.phase, GamePhase.roundComplete, reason: 'راند $round');
            final List<int> pts = e.currentPoints();
            expect(pts[0] + pts[1], e.config.totalPoints);
            expect(e.tricksWon[0] + e.tricksWon[1], e.config.totalTricks);
            expect(e.history.length, round);
            c.nextRound();
            async.elapse(const Duration(milliseconds: 400));
          }
          c.quitToMenu();
          c.dispose();
          async.flushTimers();
        });
      });

      test('ذخیره و ادامهٔ بازی وسطِ راند', () {
        fakeAsync((FakeAsync async) {
          final AppSettings s = AppSettings()..speed = GameSpeed.fast;
          s.rules = s.rulesWith(players: players);
          final GameController c =
              GameController(settings: s, random: Random(7))..newGame();
          final Random r = Random(7);
          // چند نوبت جلو می‌رویم.
          for (int i = 0; i < 25; i++) {
            final ShelemEngine e = c.engine!;
            if (e.phase == GamePhase.bidding && e.bidder == 0) {
              final int? bid = ShelemBot.chooseBid(e, 0, Difficulty.hard, rng: r);
              if (bid == null && e.canPass) {
                c.humanPass();
              } else {
                c.humanBid(bid ?? e.availableBids().first);
              }
            }
            async.elapse(const Duration(milliseconds: 400));
          }
          final ShelemEngine before = c.engine!;
          final int seats = before.seats;
          final int stock = before.stock.length;

          final GameController c2 =
              GameController(settings: s, random: Random(7));
          bool loaded = false;
          c2.loadSavedGame().then((bool ok) => loaded = ok);
          async.flushMicrotasks();
          async.elapse(const Duration(milliseconds: 50));
          expect(loaded, isTrue);
          expect(c2.engine!.seats, seats);
          expect(c2.engine!.stock.length, stock);
          expect(c2.engine!.round, before.round);

          c.dispose();
          c2.dispose();
          async.flushTimers();
        });
      });
    });
  }

  test('تعویضِ تعدادِ بازیکنان وسطِ راند تا راندِ بعد اعمال نمی‌شود', () {
    fakeAsync((FakeAsync async) {
      final AppSettings s = AppSettings()..speed = GameSpeed.fast;
      final GameController c =
          GameController(settings: s, random: Random(2))..newGame();
      async.elapse(const Duration(milliseconds: 400));
      expect(c.engine!.seats, 4);

      final AppSettings next = c.settings.copy();
      next.rules = next.rulesWith(players: 2);
      c.applySettings(next);
      async.elapse(const Duration(milliseconds: 400));
      // وسطِ راند هنوز چهار نفره است (وگرنه بازی خراب می‌شود).
      expect(c.engine!.seats, 4);
      expect(c.engine!.hands.length, 4);

      _playFullRound(async, c, Random(5));
      c.nextRound();
      async.elapse(const Duration(milliseconds: 400));
      expect(c.engine!.seats, 2);
      expect(c.engine!.hands.length, 2);
      expect(c.engine!.stock.length + 2 * 12 + 4, 52);

      c.dispose();
      async.flushTimers();
    });
  });

  test('بعد از پایان بازی، تایمر جدیدی ساخته نمی‌شود', () {
    fakeAsync((FakeAsync async) {
      final AppSettings s = AppSettings()..speed = GameSpeed.fast;
      s.rules = s.rulesWith(players: 2, targetScore: 100);
      final GameController c =
          GameController(settings: s, random: Random(11))..newGame();
      final Random r = Random(11);
      int guard = 0;
      while (c.engine!.phase != GamePhase.gameOver && guard < 12) {
        _playFullRound(async, c, r);
        if (c.engine!.phase == GamePhase.roundComplete) c.nextRound();
        async.elapse(const Duration(milliseconds: 400));
        guard++;
      }
      expect(c.engine!.phase, GamePhase.gameOver);
      expect(c.engine!.winnerTeam, isNotNull);
      // نباید تایمری باقی مانده باشد.
      async.elapse(const Duration(seconds: 5));
      expect(c.engine!.phase, GamePhase.gameOver);
      c.dispose();
      async.flushTimers();
    });
  });
}
