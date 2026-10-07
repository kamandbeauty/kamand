/// تست‌های فشار: ترکیب‌های تصادفیِ قوانین و بررسیِ ناوردایی‌های بازی.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelem/ai/bot.dart';
import 'package:shelem/game/engine.dart';
import 'package:shelem/game/scoring.dart';
import 'package:shelem/model/card.dart';
import 'package:shelem/model/enums.dart';
import 'package:shelem/state/settings.dart';

import 'sim_helper.dart';

GameConfig _randomConfig(Random r) => GameConfig(
      players: r.nextBool() ? 2 : 4,
      withJokers: r.nextBool(),
      allowShelemBid: r.nextBool(),
      allowSarShelemBid: r.nextBool(),
      forceDealerBidOnAllPass: r.nextBool(),
      targetScore: 1000000,
      scoring: ScoringRules(
        yasa: YasaRule.values[r.nextInt(YasaRule.values.length)],
        hakemAward: HakemAward.values[r.nextInt(HakemAward.values.length)],
        slamAward: SlamAward.values[r.nextInt(SlamAward.values.length)],
        opponentAlwaysScores: r.nextBool(),
      ),
    );

void main() {
  group('ناورداییِ راند با قوانینِ تصادفی', () {
    test('۱۲۰ راند با ترکیب‌های مختلفِ قوانین سالم تمام می‌شود', () {
      for (int seed = 0; seed < 120; seed++) {
        final Random r = Random(seed);
        final GameConfig cfg = _randomConfig(r);
        final ShelemEngine e = ShelemEngine(config: cfg, random: Random(seed));
        playRound(e, Difficulty.values[seed % 4], r);

        final String why = 'seed $seed / ${cfg.players} نفره / '
            'جوکر ${cfg.withJokers}';

        // همهٔ دست‌ها خالی و همهٔ برگ‌ها بازی شده‌اند.
        expect(e.hands.every((List<PlayingCard> h) => h.isEmpty), isTrue,
            reason: why);
        expect(e.stock, isEmpty, reason: why);
        expect(e.completedTricks.length, cfg.totalTricks, reason: why);
        expect(e.tricksWon[0] + e.tricksWon[1], cfg.totalTricks, reason: why);

        // هیچ برگی گم یا تکراری نشده است.
        final List<PlayingCard> all = <PlayingCard>[
          ...e.taken[0],
          ...e.taken[1],
          ...e.discards,
        ];
        expect(all.length, cfg.deckSize, reason: why);
        expect(all.toSet().length, cfg.deckSize, reason: why);

        // مجموعِ امتیازِ راند دقیقاً برابرِ مجموعِ تعریف‌شده است.
        final List<int> pts = e.currentPoints();
        expect(pts[0] + pts[1], cfg.totalPoints, reason: why);

        // هر دستِ کامل دقیقاً به تعدادِ بازیکنان برگ دارد.
        for (final CompletedTrick t in e.completedTricks) {
          expect(t.cards.length, cfg.players, reason: why);
        }

        expect(e.outcome, isNotNull, reason: why);
        expect(e.history.length, 1, reason: why);
      }
    });

    test('هیچ برگِ غیرمجازی بازی نمی‌شود', () {
      for (int seed = 0; seed < 40; seed++) {
        final Random r = Random(seed + 500);
        final GameConfig cfg = _randomConfig(r);
        final ShelemEngine e = ShelemEngine(config: cfg, random: Random(seed));
        e.startRound();
        int guard = 0;
        while (e.phase != GamePhase.roundComplete &&
            e.phase != GamePhase.gameOver &&
            guard < 5000) {
          if (e.phase == GamePhase.playing ||
              e.phase == GamePhase.declaringTrump) {
            final int p = e.turn;
            final List<PlayingCard> legal = e.legalFor(p);
            expect(legal, isNotEmpty, reason: 'seed $seed فاز ${e.phase}');
            for (final PlayingCard c in legal) {
              expect(e.hands[p].contains(c), isTrue);
              expect(e.canPlay(p, c), isTrue);
            }
          }
          botStep(e, Difficulty.hard, r);
          guard++;
        }
        expect(guard, lessThan(5000), reason: 'seed $seed گیر کرد');
      }
    });

    test('تغییرِ تعدادِ بازیکنان بینِ راندها بازی را خراب نمی‌کند', () {
      final Random r = Random(3);
      final ShelemEngine e = ShelemEngine(
        config: const GameConfig(targetScore: 1000000),
        random: r,
      );
      for (int i = 0; i < 8; i++) {
        e.config = GameConfig(
          players: i.isEven ? 4 : 2,
          targetScore: 1000000,
        );
        playRound(e, Difficulty.hard, r);
        final List<int> pts = e.currentPoints();
        expect(pts[0] + pts[1], e.config.totalPoints);
        expect(e.hands.length, e.config.players);
        expect(e.bids.length, e.config.players);
        expect(e.passed.length, e.config.players);
      }
      expect(e.history.length, 8);
    });
  });

  group('ذخیره‌سازیِ مقاومِ تنظیمات', () {
    test('نامِ enumها ذخیره و خوانده می‌شود', () {
      final AppSettings s = AppSettings()
        ..surface = TableSurface.carpetSilk
        ..difficulty = Difficulty.easy
        ..speed = GameSpeed.fast
        ..cardBack = CardBack.gold;
      final AppSettings back =
          AppSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.surface, TableSurface.carpetSilk);
      expect(back.difficulty, Difficulty.easy);
      expect(back.speed, GameSpeed.fast);
      expect(back.cardBack, CardBack.gold);
    });

    test('مقدارِ نامعتبر یا خارج از محدوده تنظیمات را خراب نمی‌کند', () {
      final AppSettings s = AppSettings.fromJson(<String, dynamic>{
        'surface': 99,
        'difficulty': 'nonsense',
        'speed': -3,
        'back': <String, dynamic>{},
      });
      expect(s.surface, TableSurface.teahouse);
      expect(s.difficulty, Difficulty.hard);
      expect(s.speed, GameSpeed.normal);
      expect(s.cardBack, CardBack.crimson);
    });

    test('زمین‌های نسخه‌های قدیمی به معادلِ تازه نگاشت می‌شوند', () {
      expect(
        AppSettings.fromJson(<String, dynamic>{'surface': 'carpetRed'}).surface,
        TableSurface.carpetAntique,
      );
      expect(
        AppSettings.fromJson(<String, dynamic>{'surface': 'carpetGreen'})
            .surface,
        TableSurface.carpetMiniature,
      );
      // شمارهٔ قدیمی (۴ = میز چوبی در نسخهٔ قبل) معتبر می‌ماند.
      expect(
        AppSettings.fromJson(<String, dynamic>{'surface': 1}).surface,
        TableSurface.values[1],
      );
    });
  });

  group('محیط‌های بازی', () {
    test('هر محیط نام، توضیح و تصویر دارد', () {
      for (final TableSurface t in TableSurface.values) {
        expect(t.fa.trim(), isNotEmpty);
        expect(t.faHint.trim(), isNotEmpty);
        if (t != TableSurface.greenFelt) {
          expect(t.asset, isNotNull, reason: t.name);
          expect(t.asset!.startsWith('assets/images/surfaces/'), isTrue);
          expect(File(t.asset!).existsSync(), isTrue,
              reason: 'فایلِ ${t.asset} پیدا نشد');
        }
      }
      expect(TableSurface.values.length, 8);
    });
  });
}
