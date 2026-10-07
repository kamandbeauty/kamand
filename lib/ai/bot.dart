/// هوش مصنوعی بازیکن‌های کامپیوتری شلم.
///
/// شامل ارزیابی دست برای مرحلهٔ خواندن، انتخاب حکم، کنار گذاشتن برگ‌های گل و
/// انتخاب کارت در جریان بازی (با شمارش کارت، تشخیص خالِ تمام‌شده، همکاری با
/// یار، بریدن و رد دادن و جمع کردن امتیاز).
library;

import 'dart:math';

import '../game/engine.dart';
import '../game/rules.dart';
import '../game/scoring.dart';
import '../model/card.dart';
import '../model/enums.dart';

class ShelemBot {
  const ShelemBot._();

  // ── ارزیابی دست ──────────────────────────────────────────────────────

  /// تخمین تعداد دست‌هایی که این دستِ کارت با حکمِ [trump] می‌گیرد.
  static double expectedTricks(List<PlayingCard> hand, Suit trump) {
    final List<PlayingCard> trumps = hand
        .where((PlayingCard c) => effectiveSuit(c, trump) == trump)
        .toList()
      ..sort((PlayingCard a, PlayingCard b) => b.rank.compareTo(a.rank));

    double tricks = 0;
    const Map<int, double> topTrump = <int, double>{
      16: 1.0,
      15: 0.95,
      14: 0.95,
      13: 0.8,
      12: 0.6,
      11: 0.4,
      10: 0.25,
    };
    for (final PlayingCard c in trumps) {
      tricks += topTrump[c.rank] ?? 0.12;
    }
    if (trumps.length > 4) tricks += (trumps.length - 4) * 0.35;
    if (tricks > trumps.length) tricks = trumps.length.toDouble();

    for (final Suit s in kRealSuits) {
      if (s == trump) continue;
      final List<PlayingCard> cards =
          hand.where((PlayingCard c) => c.suit == s).toList();
      final int len = cards.length;
      if (len == 0) {
        tricks += trumps.length >= 3 ? 0.9 : 0.35;
        continue;
      }
      double side = 0;
      for (final PlayingCard c in cards) {
        if (c.rank == 14) {
          side += 0.9;
        } else if (c.rank == 13) {
          side += len >= 2 ? 0.55 : 0.25;
        } else if (c.rank == 12) {
          side += len >= 3 ? 0.3 : 0.1;
        }
      }
      if (len == 1) side += trumps.length >= 3 ? 0.5 : 0.15;
      if (len == 2) side += trumps.length >= 4 ? 0.25 : 0.05;
      tricks += side;
    }
    return min(tricks, 12);
  }

  /// بهترین خال برای حکم‌کردن با این دست.
  static Suit bestTrump(List<PlayingCard> hand) {
    Suit best = kRealSuits.first;
    double bestScore = -1;
    for (final Suit s in kRealSuits) {
      final double v = expectedTricks(hand, s);
      if (v > bestScore) {
        bestScore = v;
        best = s;
      }
    }
    return best;
  }

  /// تخمین امتیازی که تیمِ این بازیکن می‌تواند در صورت حاکم شدن بگیرد.
  static double estimatePoints(
    List<PlayingCard> hand, {
    required bool withKitty,
    int players = 4,
    int totalPoints = 165,
  }) {
    final Suit s = bestTrump(hand);
    final double tricks = expectedTricks(hand, s);
    if (players == 2) {
      // بازی دونفره: یار نداریم، ولی فقط یک حریف هم روبه‌روی ماست.
      final double share = min(0.95, (tricks / 12) * 1.15);
      double duel = share * totalPoints * 0.92;
      if (withKitty) duel += totalPoints * 0.12;
      return min(duel, totalPoints.toDouble());
    }
    // هر دست به‌طور میانگین حدود ۱۲٫۷ امتیاز دارد (۱۶۵ ÷ ۱۳)؛ دست‌های حاکم
    // معمولاً پرامتیازترها هستند، پس کمی بالاتر گرفته می‌شود.
    double pts = tricks * 15.0;
    // سهم یار (به‌طور میانگین حدود دو دست، ولی با قوی‌تر شدن دستِ خودمان کمتر)
    pts += max(12.0, 36.0 - tricks * 1.5);
    // گلِ وسط: ۵ امتیازِ دست + امتیاز برگ‌های کنارگذاشته + بهبود دست
    if (withKitty) pts += 26;
    return min(pts, totalPoints.toDouble());
  }

  // ── مرحلهٔ خواندن ────────────────────────────────────────────────────

  /// عددی که ربات می‌خواند؛ `null` یعنی پاس.
  static int? chooseBid(
    ShelemEngine e,
    int player,
    Difficulty difficulty, {
    Random? rng,
  }) {
    final Random r = rng ?? Random();
    final List<PlayingCard> hand = e.hands[player];
    double estimate = estimatePoints(
      hand,
      withKitty: true,
      players: e.config.players,
      totalPoints: e.config.totalPoints,
    );

    // خطای انسانی در سطوح پایین
    if (difficulty.noise > 0) {
      final double spread = difficulty.noise * 40 * e.config.totalPoints / 165;
      estimate += (r.nextDouble() - 0.5) * 2 * spread;
    }
    estimate *= difficulty.bidFactor;

    // شلمِ اعلام‌شده فقط با دستِ استثنایی
    final double tricks = expectedTricks(hand, bestTrump(hand));
    if (e.config.allowShelemBid &&
        tricks >= 11.2 &&
        e.highBid < kShelemBid &&
        difficulty != Difficulty.easy) {
      return kShelemBid;
    }

    final int required = e.highBid == 0 ? e.config.minBid : e.highBid + 5;
    if (required > e.config.maxNumericBid) return null;
    if (estimate + 0.001 >= required) return required;
    return null;
  }

  // ── کنار گذاشتن برگ‌های گل ───────────────────────────────────────────

  /// انتخاب [count] برگ برای کنار گذاشتن (امتیازشان به تیم حاکم می‌رسد).
  static List<PlayingCard> chooseDiscards(
    List<PlayingCard> hand,
    int count,
    Suit trump,
  ) {
    final Map<Suit, int> len = <Suit, int>{};
    for (final PlayingCard c in hand) {
      if (effectiveSuit(c, trump) == trump) continue;
      len[c.suit] = (len[c.suit] ?? 0) + 1;
    }
    final Set<Suit> hasAce = hand
        .where((PlayingCard c) => c.rank == 14 && c.suit != trump)
        .map((PlayingCard c) => c.suit)
        .toSet();

    double score(PlayingCard c) {
      if (effectiveSuit(c, trump) == trump) return -100 + c.rank * 0.1;
      final int l = len[c.suit] ?? 0;
      double s = (5 - min(l, 5)) * 1.5; // خالِ کوتاه را خالی کن
      switch (c.rank) {
        case 14:
          s -= 9;
        case 13:
          s -= l >= 2 ? 4.5 : 1.5;
        case 12:
          s -= l >= 3 ? 2 : 0.5;
        case 10:
          // ۱۰ بدونِ آسِ پشتیبان معمولاً از دست می‌رود؛ بهتر است بانک شود.
          s += hasAce.contains(c.suit) ? -2.5 : 3.5;
        case 5:
          s += 2.0;
        default:
          s += (10 - c.rank) * 0.18;
      }
      return s;
    }

    final List<PlayingCard> sorted = List<PlayingCard>.of(hand)
      ..sort((PlayingCard a, PlayingCard b) => score(b).compareTo(score(a)));
    return sorted.take(count).toList();
  }

  // ── انتخاب کارت ──────────────────────────────────────────────────────

  /// کارت‌هایی که هنوز دیده نشده‌اند. با [memory] = false ربات فقط کارت‌های
  /// روی زمین را می‌بیند و دست‌های قبلی را به خاطر نمی‌آورد.
  static List<PlayingCard> _unseen(
    ShelemEngine e,
    int player, {
    bool memory = true,
  }) {
    final Set<PlayingCard> seen = <PlayingCard>{...e.hands[player]};
    if (memory) {
      for (final CompletedTrick t in e.completedTricks) {
        for (final PlayedCard p in t.cards) {
          seen.add(p.card);
        }
      }
    }
    for (final PlayedCard p in e.trick) {
      seen.add(p.card);
    }
    if (e.hakem == player) seen.addAll(e.discards);
    return buildDeck(withJokers: e.config.withJokers)
        .where((PlayingCard c) => !seen.contains(c))
        .toList();
  }

  static List<Set<Suit>> _voids(ShelemEngine e) {
    final List<Set<Suit>> voids = List<Set<Suit>>.generate(
      e.config.players,
      (_) => <Suit>{},
      growable: false,
    );
    void scan(List<PlayedCard> cards) {
      if (cards.isEmpty) return;
      final Suit lead = effectiveSuit(cards.first.card, e.trump);
      for (final PlayedCard p in cards.skip(1)) {
        if (effectiveSuit(p.card, e.trump) != lead) voids[p.player].add(lead);
      }
    }

    for (final CompletedTrick t in e.completedTricks) {
      scan(t.cards);
    }
    scan(e.trick);
    return voids;
  }

  static bool _isMaster(PlayingCard c, List<PlayingCard> unseen, Suit? trump) {
    final Suit es = effectiveSuit(c, trump);
    return !unseen.any((PlayingCard u) =>
        effectiveSuit(u, trump) == es && u.rank > c.rank);
  }

  static PlayingCard _lowest(List<PlayingCard> cards) => cards
      .reduce((PlayingCard a, PlayingCard b) => b.rank < a.rank ? b : a);

  static PlayingCard _highest(List<PlayingCard> cards) => cards
      .reduce((PlayingCard a, PlayingCard b) => b.rank > a.rank ? b : a);

  /// کم‌ارزش‌ترین کارت از نظر امتیاز و سپس رتبه.
  static PlayingCard _cheapest(List<PlayingCard> cards) {
    final List<PlayingCard> s = List<PlayingCard>.of(cards)
      ..sort((PlayingCard a, PlayingCard b) {
        final int p = a.points.compareTo(b.points);
        if (p != 0) return p;
        return a.rank.compareTo(b.rank);
      });
    return s.first;
  }

  /// کارتی که ربات بازی می‌کند.
  static PlayingCard chooseCard(
    ShelemEngine e,
    int player,
    Difficulty difficulty, {
    Random? rng,
  }) {
    final Random r = rng ?? Random();
    final List<PlayingCard> legal = e.legalFor(player);
    if (legal.length == 1) return legal.first;
    if (difficulty.noise > 0 && r.nextDouble() < difficulty.noise) {
      return legal[r.nextInt(legal.length)];
    }

    final List<PlayingCard> unseen =
        _unseen(e, player, memory: difficulty.countsCards);
    // در بازی دونفره تا وقتی برگ‌های روی هم تمام نشده، «نداشتنِ خال» دائمی
    // نیست؛ بازیکن ممکن است دوباره از همان خال بکشد.
    final bool trustVoids = difficulty.countsCards && e.stock.isEmpty;
    final List<Set<Suit>> voids = trustVoids
        ? _voids(e)
        : List<Set<Suit>>.generate(e.config.players, (_) => <Suit>{});

    if (e.trick.isEmpty) {
      return _lead(e, player, legal, unseen, voids);
    }
    return _follow(e, player, legal, unseen, voids);
  }

  // ── شروع‌کنندهٔ دست ──────────────────────────────────────────────────
  static PlayingCard _lead(
    ShelemEngine e,
    int player,
    List<PlayingCard> legal,
    List<PlayingCard> unseen,
    List<Set<Suit>> voids,
  ) {
    final Suit? trump = e.trump;
    final List<PlayingCard> hand = legal;
    final List<PlayingCard> trumps = hand
        .where((PlayingCard c) => isTrumpCard(c, trump))
        .toList();
    final List<PlayingCard> side = hand
        .where((PlayingCard c) => !isTrumpCard(c, trump))
        .toList();
    final int seats = e.config.players;
    final List<int> opponents = <int>[
      for (int i = 1; i < seats; i++)
        if (teamOf((player + i) % seats) != teamOf(player)) (player + i) % seats,
    ];
    final int trumpsOut = unseen
        .where((PlayingCard c) => isTrumpCard(c, trump))
        .length;
    final bool oppHasTrump = trumpsOut > 0 &&
        opponents.any((int o) => trump == null || !voids[o].contains(trump));

    // ۱) کشیدن حکم: با حکمِ زیاد و قوی، حکم‌های حریف را بیرون بکش
    if (trumps.length >= 4 && oppHasTrump) {
      final List<PlayingCard> masters = trumps
          .where((PlayingCard c) => _isMaster(c, unseen, trump))
          .toList();
      if (masters.isNotEmpty) return _highest(masters);
      if (trumps.length >= 6) return _highest(trumps);
    }

    // ۲) نقد کردن برگ‌های برنده (آس‌ها) وقتی خطر بریدن کم است
    final List<PlayingCard> masters = side
        .where((PlayingCard c) => _isMaster(c, unseen, trump))
        .toList();
    if (masters.isNotEmpty) {
      final List<PlayingCard> safe = masters.where((PlayingCard c) {
        if (trumpsOut == 0) return true;
        return !opponents.any((int o) =>
            voids[o].contains(c.suit) &&
            (trump == null || !voids[o].contains(trump)));
      }).toList();
      if (safe.isNotEmpty) {
        // از خالی که بلندتر است شروع کن
        safe.sort((PlayingCard a, PlayingCard b) {
          final int la = hand.where((PlayingCard c) => c.suit == a.suit).length;
          final int lb = hand.where((PlayingCard c) => c.suit == b.suit).length;
          if (la != lb) return lb.compareTo(la);
          return b.rank.compareTo(a.rank);
        });
        return safe.first;
      }
    }

    // ۳) اگر حکمِ حریفان تمام شده، بلندترین خالِ خودت را بزن
    if (trumpsOut == 0 && side.isNotEmpty) {
      final Map<Suit, int> len = <Suit, int>{};
      for (final PlayingCard c in side) {
        len[c.suit] = (len[c.suit] ?? 0) + 1;
      }
      final Suit longest = len.entries
          .reduce((MapEntry<Suit, int> a, MapEntry<Suit, int> b) =>
              b.value > a.value ? b : a)
          .key;
      return _highest(
        side.where((PlayingCard c) => c.suit == longest).toList(),
      );
    }

    // ۴) کارتِ کم‌ارزش از کوتاه‌ترین خال، برای خالی کردن و بریدن در دست بعد
    if (side.isNotEmpty) {
      final Map<Suit, int> len = <Suit, int>{};
      for (final PlayingCard c in side) {
        len[c.suit] = (len[c.suit] ?? 0) + 1;
      }
      final List<PlayingCard> pool = side
          .where((PlayingCard c) => !_isMaster(c, unseen, trump))
          .toList();
      final List<PlayingCard> from = pool.isNotEmpty ? pool : side;
      from.sort((PlayingCard a, PlayingCard b) {
        final int pa = a.points.compareTo(b.points);
        if (pa != 0) return pa;
        final int la = len[a.suit] ?? 0;
        final int lb = len[b.suit] ?? 0;
        if (la != lb) return la.compareTo(lb);
        return a.rank.compareTo(b.rank);
      });
      return from.first;
    }

    return _highest(trumps);
  }

  // ── جواب دادن ────────────────────────────────────────────────────────
  static PlayingCard _follow(
    ShelemEngine e,
    int player,
    List<PlayingCard> legal,
    List<PlayingCard> unseen,
    List<Set<Suit>> voids,
  ) {
    final Suit? trump = e.trump;
    final Suit lead = effectiveSuit(e.trick.first.card, trump);
    final int wi = trickWinnerIndex(e.trick, trump);
    final PlayedCard best = e.trick[wi];
    final bool partnerWinning = teamOf(best.player) == teamOf(player);
    final bool isLast = e.trick.length == e.config.players - 1;
    final int trickPoints =
        cardPointsOf(e.trick.map((PlayedCard p) => p.card));

    final List<PlayingCard> following = legal
        .where((PlayingCard c) => effectiveSuit(c, trump) == lead)
        .toList();

    bool beatsBest(PlayingCard c) => cardBeats(
          card: c,
          best: best.card,
          trump: trump,
          leadSuit: lead,
        );

    // ---------- از خالِ زمین دارم ----------
    if (following.isNotEmpty) {
      final List<PlayingCard> winners =
          following.where(beatsBest).toList();

      if (partnerWinning) {
        final bool safe =
            isLast || _isMaster(best.card, unseen, trump) || best.card.isJoker;
        if (safe) return _schmear(following, unseen, trump);
        if (winners.isNotEmpty) {
          final List<PlayingCard> sure = winners
              .where((PlayingCard c) => _isMaster(c, unseen, trump))
              .toList();
          if (sure.isNotEmpty) return _lowest(sure);
        }
        return _cheapest(following);
      }

      if (winners.isNotEmpty) {
        if (isLast) return _lowest(winners);
        final List<PlayingCard> sure = winners
            .where((PlayingCard c) => _isMaster(c, unseen, trump))
            .toList();
        if (sure.isNotEmpty) return _lowest(sure);
        if (trickPoints >= 10) return _highest(winners);
        final List<PlayingCard> strong = winners
            .where((PlayingCard c) => c.rank >= 12)
            .toList();
        if (strong.isNotEmpty) return _lowest(strong);
        return _cheapest(following);
      }
      return _cheapest(following);
    }

    // ---------- از خالِ زمین ندارم: بریدن یا رد دادن ----------
    final List<PlayingCard> trumps =
        legal.where((PlayingCard c) => isTrumpCard(c, trump)).toList();
    final List<PlayingCard> others =
        legal.where((PlayingCard c) => !isTrumpCard(c, trump)).toList();

    if (partnerWinning) {
      final bool safe =
          isLast || _isMaster(best.card, unseen, trump) || best.card.isJoker;
      if (safe) {
        // امتیاز به یار برسان
        return others.isNotEmpty
            ? _schmear(others, unseen, trump)
            : _lowest(trumps);
      }
      if (trumps.isNotEmpty) {
        final List<PlayingCard> over = trumps.where(beatsBest).toList();
        if (over.isNotEmpty) return _lowest(over);
      }
      return others.isNotEmpty ? _cheapest(others) : _lowest(trumps);
    }

    if (trumps.isNotEmpty) {
      final List<PlayingCard> over = trumps.where(beatsBest).toList();
      if (over.isNotEmpty) {
        if (isLast) return _lowest(over);
        final int seats = e.config.players;
        final List<int> after = <int>[];
        for (int k = 1; k <= seats - 1 - e.trick.length; k++) {
          after.add((player + k) % seats);
        }
        final bool oppCanOverTrump = after.any((int p) =>
            teamOf(p) != teamOf(player) &&
            (trump == null || !voids[p].contains(trump)));
        if (!oppCanOverTrump) return _lowest(over);
        final List<PlayingCard> sure = over
            .where((PlayingCard c) => _isMaster(c, unseen, trump))
            .toList();
        if (sure.isNotEmpty) return _lowest(sure);
        // دستِ پرامتیاز ارزش ریسک دارد
        return trickPoints >= 10 ? _highest(over) : _lowest(over);
      }
    }
    return others.isNotEmpty ? _cheapest(others) : _lowest(trumps);
  }

  /// وقتی تیم خودمان برنده است، پرامتیازترین کارتِ غیرضروری را می‌اندازیم.
  static PlayingCard _schmear(
    List<PlayingCard> cards,
    List<PlayingCard> unseen,
    Suit? trump,
  ) {
    final List<PlayingCard> pointCards = cards
        .where((PlayingCard c) =>
            c.points > 0 && !(c.rank == 14 && !_isMaster(c, unseen, trump)))
        .toList();
    // آس را فقط وقتی می‌اندازیم که دیگر برنده نباشد یا چاره‌ای نباشد
    final List<PlayingCard> notAce =
        pointCards.where((PlayingCard c) => c.rank != 14).toList();
    if (notAce.isNotEmpty) {
      notAce.sort((PlayingCard a, PlayingCard b) {
        final int p = b.points.compareTo(a.points);
        if (p != 0) return p;
        return a.rank.compareTo(b.rank);
      });
      return notAce.first;
    }
    return _cheapest(cards);
  }
}
