/// موتور کامل بازی شلم: پخش کارت، حراج، گل، اعلام حکم، بازی دست‌ها و امتیاز.
///
/// نشستن بازیکنان (پادساعتگرد):
///   ۰ = شما (پایین) ، ۱ = حریف راست ، ۲ = یار شما (بالا) ، ۳ = حریف چپ
///   تیم ۰ = بازیکنان ۰ و ۲ ، تیم ۱ = بازیکنان ۱ و ۳
library;

import 'dart:math';

import '../model/card.dart';
import 'rules.dart';
import 'scoring.dart';

/// فازهای بازی.
enum GamePhase {
  /// پخش کارت‌ها
  dealing,

  /// مرحلهٔ خواندن (حراج)
  bidding,

  /// حاکم چهار (یا شش) برگِ گل را می‌بیند
  kitty,

  /// حاکم باید همان تعداد برگ کنار بگذارد
  discarding,

  /// اولین برگِ حاکم، حکم را تعیین می‌کند
  declaringTrump,

  /// جریان عادی بازی
  playing,

  /// دست کامل شد و منتظر جمع‌آوری است
  trickComplete,

  /// راند تمام شد
  roundComplete,

  /// بازی تمام شد
  gameOver,
}

/// تیم هر بازیکن.
int teamOf(int player) => player % 2;

/// نفر بعدی (پادساعتگرد).
int nextPlayer(int player) => (player + 1) % 4;

/// تنظیمات قانونیِ یک بازی.
class GameConfig {
  const GameConfig({
    this.withJokers = false,
    this.allowShelemBid = true,
    this.allowSarShelemBid = false,
    this.forceDealerBidOnAllPass = false,
    this.targetScore = 1165,
    this.scoring = const ScoringRules(),
  });

  /// بازی با دو جوکر (۲۰۰ امتیازی) به‌جای ۱۶۵ امتیازی.
  final bool withJokers;

  /// اجازهٔ خواندنِ «شلم» بعد از بالاترین عدد.
  final bool allowShelemBid;

  /// اجازهٔ خواندنِ «سرشلم» (شلمِ بسته، بدون دیدن گل).
  final bool allowSarShelemBid;

  /// اگر هر چهار نفر پاس بدهند، صاحبِ دست مجبور به خواندنِ حداقل شود
  /// (در غیر این صورت کارت‌ها دوباره پخش می‌شوند).
  final bool forceDealerBidOnAllPass;

  /// امتیاز پایان بازی.
  final int targetScore;

  final ScoringRules scoring;

  int get handSize => 12;
  int get kittySize => withJokers ? 6 : 4;
  int get minBid => withJokers ? 120 : 100;
  int get maxNumericBid => withJokers ? 200 : 165;

  /// مجموع امتیاز قابل کسب در هر راند (۱۶۵ یا ۲۰۰).
  int get totalPoints => withJokers ? 200 : 165;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'jokers': withJokers,
        'shelem': allowShelemBid,
        'sar': allowSarShelemBid,
        'force': forceDealerBidOnAllPass,
        'target': targetScore,
        'scoring': scoring.toJson(),
      };

  static GameConfig fromJson(Map<String, dynamic> j) => GameConfig(
        withJokers: (j['jokers'] as bool?) ?? false,
        allowShelemBid: (j['shelem'] as bool?) ?? true,
        allowSarShelemBid: (j['sar'] as bool?) ?? false,
        forceDealerBidOnAllPass: (j['force'] as bool?) ?? false,
        targetScore: (j['target'] as int?) ?? 1165,
        scoring: ScoringRules.fromJson(
          Map<String, dynamic>.from(
            (j['scoring'] as Map?) ?? const <String, dynamic>{},
          ),
        ),
      );
}

/// یک سطر از جدول امتیازها.
class RoundRecord {
  const RoundRecord({
    required this.round,
    required this.hakem,
    required this.trump,
    required this.outcome,
    required this.totals,
  });

  final int round;
  final int hakem;
  final Suit? trump;
  final RoundOutcome outcome;
  final List<int> totals;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'r': round,
        'h': hakem,
        't': trump?.index,
        'o': outcome.toJson(),
        'tot': totals,
      };

  static RoundRecord fromJson(Map<String, dynamic> j) => RoundRecord(
        round: j['r'] as int,
        hakem: j['h'] as int,
        trump: j['t'] == null ? null : Suit.values[j['t'] as int],
        outcome: RoundOutcome.fromJson(
          Map<String, dynamic>.from(j['o'] as Map),
        ),
        totals: List<int>.from(j['tot'] as List<dynamic>),
      );
}

/// یک دستِ کامل‌شده (برای مرور دست‌های قبلی).
class CompletedTrick {
  const CompletedTrick({
    required this.index,
    required this.cards,
    required this.winner,
    required this.points,
  });

  final int index;
  final List<PlayedCard> cards;
  final int winner;
  final int points;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'i': index,
        'c': cards.map((PlayedCard p) => p.toJson()).toList(),
        'w': winner,
        'p': points,
      };

  static CompletedTrick fromJson(Map<String, dynamic> j) => CompletedTrick(
        index: j['i'] as int,
        cards: (j['c'] as List<dynamic>)
            .map((dynamic e) =>
                PlayedCard.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        winner: j['w'] as int,
        points: j['p'] as int,
      );
}

/// موتور بازی. تمام قوانین اینجا اعمال می‌شوند و رابط کاربری فقط آن را صدا می‌زند.
class ShelemEngine {
  ShelemEngine({GameConfig? config, Random? random})
      : config = config ?? const GameConfig(),
        _random = random ?? Random();

  GameConfig config;
  final Random _random;

  // ── وضعیت کلی بازی ───────────────────────────────────────────────────
  int round = 0;
  int dealer = 3;
  List<int> scores = <int>[0, 0];
  List<RoundRecord> history = <RoundRecord>[];
  int? winnerTeam;

  // ── وضعیت راند جاری ──────────────────────────────────────────────────
  GamePhase phase = GamePhase.dealing;
  List<List<PlayingCard>> hands = <List<PlayingCard>>[
    <PlayingCard>[],
    <PlayingCard>[],
    <PlayingCard>[],
    <PlayingCard>[],
  ];
  List<PlayingCard> kitty = <PlayingCard>[];
  List<PlayingCard> discards = <PlayingCard>[];

  /// آخرین عددی که هر بازیکن خوانده است (null یعنی هنوز نخوانده).
  List<int?> bids = <int?>[null, null, null, null];
  List<bool> passed = <bool>[false, false, false, false];
  int bidder = 0;
  int highBid = 0;
  int? hakem;
  int contract = 0;

  Suit? trump;

  /// وقتی حاکم حکم را از طریق منو اعلام کند، اولین برگش باید از خالِ حکم باشد.
  bool mustLeadTrumpFirst = false;
  int leader = 0;
  int turn = 0;
  List<PlayedCard> trick = <PlayedCard>[];
  List<CompletedTrick> completedTricks = <CompletedTrick>[];
  CompletedTrick? lastTrick;

  List<int> tricksWon = <int>[0, 0];
  List<List<PlayingCard>> taken = <List<PlayingCard>>[
    <PlayingCard>[],
    <PlayingCard>[],
  ];

  RoundOutcome? outcome;

  /// وقتی حاکم جوکر را به‌عنوان اولین برگ بازی کند باید خال حکم را اعلام کند.
  bool get awaitingJokerTrump =>
      phase == GamePhase.declaringTrump && trick.isNotEmpty && trump == null;

  // ── شروع راند ────────────────────────────────────────────────────────
  void startRound() {
    round += 1;
    dealer = nextPlayer(dealer);
    phase = GamePhase.dealing;
    hands = List<List<PlayingCard>>.generate(4, (_) => <PlayingCard>[]);
    kitty = <PlayingCard>[];
    discards = <PlayingCard>[];
    bids = <int?>[null, null, null, null];
    passed = <bool>[false, false, false, false];
    highBid = 0;
    hakem = null;
    contract = 0;
    trump = null;
    mustLeadTrumpFirst = false;
    trick = <PlayedCard>[];
    completedTricks = <CompletedTrick>[];
    lastTrick = null;
    tricksWon = <int>[0, 0];
    taken = <List<PlayingCard>>[<PlayingCard>[], <PlayingCard>[]];
    outcome = null;

    final List<PlayingCard> deck = buildDeck(withJokers: config.withJokers)
      ..shuffle(_random);

    // پخش در سه دور چهارتایی، شروع از دستِ راستِ صاحب‌دست
    int p = nextPlayer(dealer);
    for (int round3 = 0; round3 < 3; round3++) {
      for (int k = 0; k < 4; k++) {
        for (int i = 0; i < 4; i++) {
          hands[p].add(deck.removeLast());
        }
        p = nextPlayer(p);
      }
    }
    // باقیِ کارت‌ها «گل» وسط زمین
    kitty = <PlayingCard>[
      for (int i = 0; i < config.kittySize; i++) deck.removeLast(),
    ];
    assert(deck.isEmpty, 'تمام کارت‌ها باید پخش شوند');
    for (final List<PlayingCard> h in hands) {
      h.sort();
    }

    bidder = nextPlayer(dealer);
    phase = GamePhase.bidding;
  }

  // ── مرحلهٔ خواندن ────────────────────────────────────────────────────

  /// عددهای مجاز برای خواندنِ بازیکنِ فعلی.
  List<int> availableBids() {
    final List<int> out = <int>[];
    final int start = highBid == 0 ? config.minBid : highBid + 5;
    for (int v = start; v <= config.maxNumericBid; v += 5) {
      out.add(v);
    }
    if (config.allowShelemBid && highBid < kShelemBid) out.add(kShelemBid);
    if (config.allowSarShelemBid && highBid < kSarShelemBid) {
      out.add(kSarShelemBid);
    }
    return out;
  }

  bool canBid(int value) => availableBids().contains(value);

  /// خواندنِ یک عدد توسط بازیکنِ نوبت‌دار.
  void placeBid(int value) {
    assert(phase == GamePhase.bidding);
    if (!canBid(value)) {
      throw ArgumentError('عدد $value برای خواندن مجاز نیست');
    }
    bids[bidder] = value;
    highBid = value;
    hakem = bidder;
    _advanceBidding();
  }

  /// پاس دادنِ بازیکنِ نوبت‌دار.
  void passBid() {
    assert(phase == GamePhase.bidding);
    passed[bidder] = true;
    _advanceBidding();
  }

  void _advanceBidding() {
    final int remaining = passed.where((bool p) => !p).length;

    if (remaining == 0) {
      // هر چهار نفر پاس دادند
      if (config.forceDealerBidOnAllPass) {
        hakem = dealer;
        highBid = config.minBid;
        bids[dealer] = config.minBid;
        _startKittyPhase();
      } else {
        // کارت‌ها دوباره پخش می‌شود (همان صاحب‌دست حفظ می‌شود)
        round -= 1;
        dealer = (dealer + 3) % 4;
        startRound();
      }
      return;
    }

    if (remaining == 1 && highBid > 0) {
      final int only = passed.indexWhere((bool p) => !p);
      if (only == hakem) {
        _startKittyPhase();
        return;
      }
    }

    // نوبت به نفر بعدی که پاس نداده است
    int next = nextPlayer(bidder);
    int guard = 0;
    while (passed[next] && guard < 8) {
      next = nextPlayer(next);
      guard++;
    }
    bidder = next;
  }

  void _startKittyPhase() {
    contract = highBid;
    if (contract == kSarShelemBid) {
      // شلمِ بسته: حاکم گل را نمی‌بیند؛ برگ‌های گل جزو برده‌های تیم او هستند.
      discards = List<PlayingCard>.of(kitty);
      kitty = <PlayingCard>[];
      _beginPlay();
    } else {
      phase = GamePhase.kitty;
    }
  }

  /// حاکم گل را برمی‌دارد (کارت‌ها وارد دستش می‌شوند).
  void takeKitty() {
    assert(phase == GamePhase.kitty);
    hands[hakem!].addAll(kitty);
    hands[hakem!].sort();
    kitty = <PlayingCard>[];
    phase = GamePhase.discarding;
  }

  /// حاکم به تعداد برگ‌های گل، کارت کنار می‌گذارد.
  /// امتیاز این برگ‌ها به تیم حاکم تعلق می‌گیرد.
  void discardCards(List<PlayingCard> cards) {
    assert(phase == GamePhase.discarding);
    if (cards.length != config.kittySize) {
      throw ArgumentError('باید دقیقاً ${config.kittySize} برگ کنار بگذارید');
    }
    final List<PlayingCard> hand = hands[hakem!];
    for (final PlayingCard c in cards) {
      if (!hand.remove(c)) {
        throw ArgumentError('کارت ${c.id} در دست حاکم نیست');
      }
    }
    discards = List<PlayingCard>.of(cards);
    _beginPlay();
  }

  void _beginPlay() {
    leader = hakem!;
    turn = hakem!;
    phase = GamePhase.declaringTrump;
  }

  // ── بازی کردن ────────────────────────────────────────────────────────

  Suit? get leadSuit =>
      trick.isEmpty ? null : effectiveSuit(trick.first.card, trump);

  /// کارت‌های مجاز برای بازیکنِ [player].
  List<PlayingCard> legalFor(int player) {
    if (mustLeadTrumpFirst &&
        player == hakem &&
        trick.isEmpty &&
        completedTricks.isEmpty) {
      final List<PlayingCard> t = hands[player]
          .where((PlayingCard c) => isTrumpCard(c, trump))
          .toList();
      if (t.isNotEmpty) return t;
    }
    return legalCards(
      hand: hands[player],
      leadSuit: trick.isEmpty ? null : leadSuit,
      trump: trump,
    );
  }

  bool canPlay(int player, PlayingCard card) {
    if (phase != GamePhase.playing && phase != GamePhase.declaringTrump) {
      return false;
    }
    if (turn != player) return false;
    return legalFor(player).contains(card);
  }

  /// بازی کردن یک برگ.
  ///
  /// اگر این اولین برگِ راند باشد (توسط حاکم)، خالِ همان برگ «حکم» می‌شود.
  /// اگر حاکم جوکر بازی کند باید [declaredTrump] را هم بدهد.
  void playCard(int player, PlayingCard card, {Suit? declaredTrump}) {
    if (!canPlay(player, card)) {
      throw StateError('بازی کردن ${card.id} توسط بازیکن $player مجاز نیست');
    }
    if (phase == GamePhase.declaringTrump) {
      if (card.isJoker) {
        if (declaredTrump == null) {
          // حکم باید جداگانه اعلام شود؛ کارت روی زمین می‌ماند.
          hands[player].remove(card);
          trick.add(PlayedCard(player, card));
          return;
        }
        trump = declaredTrump;
      } else {
        trump = card.suit;
      }
      phase = GamePhase.playing;
      if (trick.isNotEmpty) {
        // جوکر قبلاً روی زمین رفته و حالا حکم اعلام شد
        turn = nextPlayer(player);
        return;
      }
    }

    hands[player].remove(card);
    trick.add(PlayedCard(player, card));
    mustLeadTrumpFirst = false;

    if (trick.length == 4) {
      phase = GamePhase.trickComplete;
    } else {
      turn = nextPlayer(player);
    }
  }

  /// اعلام حکم پیش از انداختن اولین برگ (حالت «انتخاب خال از منو»).
  /// طبق قانون، اولین برگِ حاکم باید از همان خال باشد.
  void declareTrumpBeforeLead(Suit suit) {
    assert(phase == GamePhase.declaringTrump && trick.isEmpty);
    trump = suit;
    mustLeadTrumpFirst = true;
    phase = GamePhase.playing;
  }

  /// اعلام خال حکم وقتی حاکم با جوکر شروع کرده است.
  void declareTrumpSuit(Suit suit) {
    assert(awaitingJokerTrump);
    trump = suit;
    phase = GamePhase.playing;
    turn = nextPlayer(trick.first.player);
  }

  /// جمع کردن دست و تعیین برنده.
  void collectTrick() {
    assert(phase == GamePhase.trickComplete);
    final int winner = trickWinner(trick, trump);
    final int team = teamOf(winner);
    tricksWon[team] += 1;
    taken[team].addAll(trick.map((PlayedCard p) => p.card));
    final CompletedTrick done = CompletedTrick(
      index: completedTricks.length + 1,
      cards: List<PlayedCard>.of(trick),
      winner: winner,
      points: trickScore(trick),
    );
    completedTricks.add(done);
    lastTrick = done;
    trick = <PlayedCard>[];
    leader = winner;
    turn = winner;

    if (hands.every((List<PlayingCard> h) => h.isEmpty)) {
      _finishRound();
    } else {
      phase = GamePhase.playing;
    }
  }

  /// امتیاز جمع‌شدهٔ هر تیم در راند جاری (شامل برگ‌های کنارگذاشتهٔ حاکم).
  List<int> currentPoints() {
    final List<int> pts = <int>[
      kTrickBonus * tricksWon[0] + cardPointsOf(taken[0]),
      kTrickBonus * tricksWon[1] + cardPointsOf(taken[1]),
    ];
    if (hakem != null && discards.isNotEmpty) {
      pts[teamOf(hakem!)] += kTrickBonus + cardPointsOf(discards);
    }
    return pts;
  }

  void _finishRound() {
    final List<int> pts = currentPoints();
    final int ht = teamOf(hakem!);
    final RoundOutcome o = scoreRound(
      hakemTeam: ht,
      contract: contract,
      hakemPoints: pts[ht],
      opponentPoints: pts[1 - ht],
      hakemWonAllTricks: tricksWon[ht] == config.handSize,
      rules: config.scoring,
    );
    outcome = o;
    scores[ht] += o.hakemDelta;
    scores[1 - ht] += o.opponentDelta;
    history.add(RoundRecord(
      round: round,
      hakem: hakem!,
      trump: trump,
      outcome: o,
      totals: List<int>.of(scores),
    ));

    if (scores[0] >= config.targetScore || scores[1] >= config.targetScore) {
      if (scores[0] != scores[1]) {
        winnerTeam = scores[0] > scores[1] ? 0 : 1;
        phase = GamePhase.gameOver;
        return;
      }
    }
    phase = GamePhase.roundComplete;
  }

  // ── ذخیره و بازیابی ──────────────────────────────────────────────────
  Map<String, dynamic> toJson() => <String, dynamic>{
        'config': config.toJson(),
        'round': round,
        'dealer': dealer,
        'scores': scores,
        'history': history.map((RoundRecord r) => r.toJson()).toList(),
        'winner': winnerTeam,
        'phase': phase.index,
        'hands': hands
            .map((List<PlayingCard> h) =>
                h.map((PlayingCard c) => c.toJson()).toList())
            .toList(),
        'kitty': kitty.map((PlayingCard c) => c.toJson()).toList(),
        'discards': discards.map((PlayingCard c) => c.toJson()).toList(),
        'bids': bids,
        'passed': passed,
        'bidder': bidder,
        'highBid': highBid,
        'hakem': hakem,
        'contract': contract,
        'trump': trump?.index,
        'mustLeadTrump': mustLeadTrumpFirst,
        'leader': leader,
        'turn': turn,
        'trick': trick.map((PlayedCard p) => p.toJson()).toList(),
        'done': completedTricks.map((CompletedTrick t) => t.toJson()).toList(),
        'tricksWon': tricksWon,
        'taken': taken
            .map((List<PlayingCard> t) =>
                t.map((PlayingCard c) => c.toJson()).toList())
            .toList(),
        'outcome': outcome?.toJson(),
      };

  static List<PlayingCard> _cards(dynamic raw) => (raw as List<dynamic>)
      .map((dynamic e) =>
          PlayingCard.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  static ShelemEngine fromJson(Map<String, dynamic> j, {Random? random}) {
    final ShelemEngine e = ShelemEngine(
      config: GameConfig.fromJson(
        Map<String, dynamic>.from(j['config'] as Map),
      ),
      random: random,
    );
    e.round = j['round'] as int;
    e.dealer = j['dealer'] as int;
    e.scores = List<int>.from(j['scores'] as List<dynamic>);
    e.history = (j['history'] as List<dynamic>)
        .map((dynamic r) =>
            RoundRecord.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    e.winnerTeam = j['winner'] as int?;
    e.phase = GamePhase.values[j['phase'] as int];
    e.hands = (j['hands'] as List<dynamic>)
        .map<List<PlayingCard>>((dynamic h) => _cards(h))
        .toList();
    e.kitty = _cards(j['kitty']);
    e.discards = _cards(j['discards']);
    e.bids = (j['bids'] as List<dynamic>).map((dynamic b) => b as int?).toList();
    e.passed = (j['passed'] as List<dynamic>).map((dynamic b) => b as bool).toList();
    e.bidder = j['bidder'] as int;
    e.highBid = j['highBid'] as int;
    e.hakem = j['hakem'] as int?;
    e.contract = j['contract'] as int;
    e.trump = j['trump'] == null ? null : Suit.values[j['trump'] as int];
    e.mustLeadTrumpFirst = (j['mustLeadTrump'] as bool?) ?? false;
    e.leader = j['leader'] as int;
    e.turn = j['turn'] as int;
    e.trick = (j['trick'] as List<dynamic>)
        .map((dynamic p) =>
            PlayedCard.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    e.completedTricks = (j['done'] as List<dynamic>)
        .map((dynamic t) =>
            CompletedTrick.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();
    e.lastTrick =
        e.completedTricks.isEmpty ? null : e.completedTricks.last;
    e.tricksWon = List<int>.from(j['tricksWon'] as List<dynamic>);
    e.taken = (j['taken'] as List<dynamic>)
        .map<List<PlayingCard>>((dynamic t) => _cards(t))
        .toList();
    e.outcome = j['outcome'] == null
        ? null
        : RoundOutcome.fromJson(Map<String, dynamic>.from(j['outcome'] as Map));
    return e;
  }
}
