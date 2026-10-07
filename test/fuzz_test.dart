/// تستِ فازی: هزاران راند با تنظیماتِ گوناگون بازی می‌شود تا هر خطا،
/// حرکتِ غیرمجاز، قفل‌شدن یا به‌هم‌ریختنِ امتیازها پیدا شود.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelem/ai/bot.dart';
import 'package:shelem/game/engine.dart';
import 'package:shelem/game/rules.dart';
import 'package:shelem/game/scoring.dart';
import 'package:shelem/model/card.dart';
import 'package:shelem/model/enums.dart';

/// یک گامِ بازی با بررسیِ کاملِ قانونی بودنِ حرکت.
void _step(ShelemEngine e, Difficulty d, Random r) {
  switch (e.phase) {
    case GamePhase.dealing:
      e.startRound();
    case GamePhase.bidding:
      final int? bid = ShelemBot.chooseBid(e, e.bidder, d, rng: r);
      if (bid == null || !e.canBid(bid)) {
        if (e.canPass) {
          e.passBid();
        } else {
          e.placeBid(e.availableBids().first);
        }
      } else {
        e.placeBid(bid);
      }
    case GamePhase.kitty:
      e.takeKitty();
    case GamePhase.discarding:
      final List<PlayingCard> hand = e.hands[e.hakem!];
      final Suit trump = ShelemBot.bestTrump(hand);
      final List<PlayingCard> d4 =
          ShelemBot.chooseDiscards(hand, e.config.kittySize, trump);
      expect(d4.length, e.config.kittySize);
      expect(d4.toSet().length, d4.length, reason: 'برگ تکراری کنار گذاشته شد');
      for (final PlayingCard c in d4) {
        expect(hand.contains(c), isTrue, reason: 'برگِ بیرون از دست');
      }
      e.discardCards(d4);
    case GamePhase.declaringTrump:
    case GamePhase.playing:
      final int p = e.turn;
      final PlayingCard card = e.phase == GamePhase.declaringTrump
          ? _firstLead(e, p)
          : ShelemBot.chooseCard(e, p, d, rng: r);
      expect(
        e.legalFor(p).contains(card),
        isTrue,
        reason: 'کارتِ غیرمجاز ${card.id} در فاز ${e.phase}',
      );
      e.playCard(
        p,
        card,
        declaredTrump: card.isJoker ? ShelemBot.bestTrump(e.hands[p]) : null,
      );
    case GamePhase.trickComplete:
      expect(e.trick.length, 4);
      e.collectTrick();
    case GamePhase.roundComplete:
    case GamePhase.gameOver:
      break;
  }
}

PlayingCard _firstLead(ShelemEngine e, int p) {
  final Suit trump = ShelemBot.bestTrump(e.hands[p]);
  final List<PlayingCard> legal = e.legalFor(p);
  final List<PlayingCard> ofSuit =
      legal.where((PlayingCard c) => c.suit == trump).toList();
  if (ofSuit.isEmpty) return legal.first;
  ofSuit.sort((PlayingCard a, PlayingCard b) => b.rank.compareTo(a.rank));
  return ofSuit.first;
}

void _checkRound(ShelemEngine e) {
  final List<int> pts = e.currentPoints();
  expect(
    pts[0] + pts[1],
    e.config.totalPoints,
    reason: 'مجموع امتیازِ راند',
  );
  expect(e.tricksWon[0] + e.tricksWon[1], 12);
  expect(e.hands.every((List<PlayingCard> h) => h.isEmpty), isTrue);
  expect(e.discards.length, e.config.kittySize);
  expect(e.trick, isEmpty);
  expect(e.outcome, isNotNull);
  expect(e.completedTricks.length, 12);

  final RoundOutcome o = e.outcome!;
  // هیچ برگی گم یا تکراری نشده است
  final List<PlayingCard> all = <PlayingCard>[
    ...e.taken[0],
    ...e.taken[1],
    ...e.discards,
  ];
  expect(all.length, e.config.withJokers ? 54 : 52);
  expect(all.toSet().length, all.length, reason: 'برگِ تکراری');

  // امتیازدهی با قانون هم‌خوان است
  expect(o.contractMade, o.contract >= kShelemBid
      ? e.tricksWon[teamOf(e.hakem!)] == 12
      : pts[teamOf(e.hakem!)] >= o.contract);
}

void main() {
  final List<GameConfig> configs = <GameConfig>[
    const GameConfig(),
    const GameConfig(withJokers: true),
    const GameConfig(
      scoring: ScoringRules(
        yasa: YasaRule.off,
        hakemAward: HakemAward.actualPoints,
        slamAward: SlamAward.fixed330,
        opponentAlwaysScores: false,
      ),
    ),
    const GameConfig(
      forceDealerBidOnAllPass: true,
      allowSarShelemBid: true,
      scoring: ScoringRules(yasa: YasaRule.lessThanHalfContract),
    ),
    const GameConfig(withJokers: true, targetScore: 400),
  ];

  test('۱۰۰۰ راند با تنظیماتِ گوناگون بدونِ خطا و با امتیازِ درست', () {
    int rounds = 0;
    for (int ci = 0; ci < configs.length; ci++) {
      for (final Difficulty d in Difficulty.values) {
        for (int seed = 0; seed < 10; seed++) {
          final Random r = Random(seed * 37 + ci * 7 + d.index);
          final ShelemEngine e =
              ShelemEngine(config: configs[ci], random: r);
          for (int k = 0; k < 5; k++) {
            e.startRound();
            int guard = 0;
            while (e.phase != GamePhase.roundComplete &&
                e.phase != GamePhase.gameOver &&
                guard < 4000) {
              _step(e, d, r);
              guard++;
            }
            expect(guard, lessThan(4000), reason: 'راند تمام نشد');
            _checkRound(e);
            rounds++;
            if (e.phase == GamePhase.gameOver) break;
          }
        }
      }
    }
    expect(rounds, greaterThan(500));
  });

  test('جدولِ امتیاز همیشه برابرِ جمعِ تغییراتِ راندهاست', () {
    final Random r = Random(99);
    final ShelemEngine e = ShelemEngine(random: r);
    final List<int> sum = <int>[0, 0];
    for (int k = 0; k < 12; k++) {
      e.startRound();
      int guard = 0;
      while (e.phase != GamePhase.roundComplete &&
          e.phase != GamePhase.gameOver &&
          guard < 4000) {
        _step(e, Difficulty.hard, r);
        guard++;
      }
      final RoundOutcome o = e.outcome!;
      sum[o.hakemTeam] += o.hakemDelta;
      sum[o.opponentTeam] += o.opponentDelta;
      expect(e.scores, sum);
      expect(e.history.length, k + 1);
      if (e.phase == GamePhase.gameOver) break;
    }
  });

  test('ذخیره و بازیابی در هر فاز، بازی را دقیقاً حفظ می‌کند', () {
    final Random r = Random(5);
    final ShelemEngine e = ShelemEngine(
      config: const GameConfig(withJokers: true),
      random: r,
    );
    e.startRound();
    int guard = 0;
    while (e.phase != GamePhase.roundComplete && guard < 4000) {
      final String before = jsonEncode(e.toJson());
      final ShelemEngine copy = ShelemEngine.fromJson(
        Map<String, dynamic>.from(jsonDecode(before) as Map),
      );
      expect(jsonEncode(copy.toJson()), before, reason: 'در فاز ${e.phase}');
      _step(e, Difficulty.hard, r);
      guard++;
    }
    expect(e.phase, GamePhase.roundComplete);
  });

  test('حرکت‌های غیرمجاز رد می‌شوند', () {
    final ShelemEngine e = ShelemEngine(random: Random(1))..startRound();
    // عددِ خارج از محدوده
    expect(() => e.placeBid(97), throwsArgumentError);
    expect(() => e.placeBid(1000), throwsArgumentError);
    e.placeBid(e.config.minBid);
    // خوانندهٔ برتر حق پاس ندارد
    expect(e.canPass, isFalse);
    expect(e.passBid, throwsStateError);
    // عددِ کوچک‌تر یا مساوی مجاز نیست
    expect(() => e.placeBid(e.config.minBid), throwsArgumentError);

    while (e.phase == GamePhase.bidding) {
      if (e.canPass) {
        e.passBid();
      } else {
        e.placeBid(e.availableBids().first);
      }
    }
    e.takeKitty();
    expect(e.hands[e.hakem!].length, 12 + e.config.kittySize);
    expect(
      () => e.discardCards(e.hands[e.hakem!].take(1).toList()),
      throwsArgumentError,
    );
    e.discardCards(e.hands[e.hakem!].take(e.config.kittySize).toList());
    expect(e.hands[e.hakem!].length, 12);

    // بازیکنِ بی‌نوبت نمی‌تواند بازی کند
    final int other = nextPlayer(e.hakem!);
    expect(
      () => e.playCard(other, e.hands[other].first),
      throwsStateError,
    );
  });

  test('اجبار به خالِ زمین در تمامِ دست‌ها رعایت می‌شود', () {
    final Random r = Random(123);
    final ShelemEngine e = ShelemEngine(random: r)..startRound();
    int guard = 0;
    while (e.phase != GamePhase.roundComplete && guard < 4000) {
      if (e.phase == GamePhase.playing && e.trick.isNotEmpty) {
        final Suit lead = e.leadSuit!;
        final int p = e.turn;
        final bool has = e.hands[p]
            .any((PlayingCard c) => effectiveSuit(c, e.trump) == lead);
        final List<PlayingCard> legal = e.legalFor(p);
        if (has) {
          expect(
            legal.every(
              (PlayingCard c) => effectiveSuit(c, e.trump) == lead,
            ),
            isTrue,
          );
        } else {
          expect(legal.length, e.hands[p].length);
        }
      }
      _step(e, Difficulty.hard, r);
      guard++;
    }
  });

  test('سختیِ بالاتر، امتیازِ بیشتری از دست‌ها می‌گیرد', () {
    int pointsFor(Difficulty a, Difficulty b) {
      int mine = 0;
      for (int seed = 0; seed < 40; seed++) {
        final Random r = Random(seed);
        final ShelemEngine e = ShelemEngine(random: r);
        e.startRound();
        int guard = 0;
        while (e.phase != GamePhase.roundComplete && guard < 4000) {
          final Difficulty d = teamOf(e.turn) == 0 ? a : b;
          _step(e, d, r);
          guard++;
        }
        mine += e.currentPoints()[0];
      }
      return mine;
    }

    final int strong = pointsFor(Difficulty.hard, Difficulty.easy);
    final int weak = pointsFor(Difficulty.easy, Difficulty.hard);
    expect(strong, greaterThan(weak));
  });
}
