import 'dart:math';

import 'engine_events.dart';
import 'game_event_listener.dart';
import 'managers/deal_manager.dart';
import 'managers/hukum_manager.dart';
import 'managers/turn_manager.dart';
import 'models/deck.dart';
import 'models/player.dart';
import 'models/playing_card.dart';
import 'models/suit.dart';
import 'models/team.dart';
import 'models/trick.dart';
import 'rules/game_rules.dart';
import 'scoring/score_manager.dart';
import 'state/game_enums.dart';
import 'state/game_state.dart';

/// موتور اصلی حکم — منطق خالص، بدون وابستگی به Flutter/Flame.
///
/// چرخهٔ حیات:
/// ```
/// startMatch() → determineHakim() → startRound()
///   → selectTrump() → playCard() × ۵۲ → (startRound() × N) → پایان مسابقه
/// ```
///
/// همهٔ وضعیت در [state] است و سریالایزپذیر است. UI از طریق رویدادها
/// (addListener) خبر می‌شود. انتخاب.Random تزریق‌شده تست‌ها را قطعی می‌کند.
class HokmEngine {
  HokmEngine({
    Random? random,
    int matchTarget = ScoreManager.defaultMatchTarget,
  })  : _random = random ?? Random(),
        _scoreManager = ScoreManager(matchTarget: matchTarget);

  final Random _random;
  final ScoreManager _scoreManager;
  final DealManager _dealManager = DealManager();

  HukumManager _hukumManager = HukumManager();
  TurnManager? _turnManager;

  GameState? _state;
  final List<GameEventListener> _listeners = <GameEventListener>[];

  // ---------- دسترسی ----------

  GameState get state {
    final s = _state;
    if (s == null) throw StateError('Match has not started yet');
    return s;
  }

  bool get isMatchStarted => _state != null;
  Seat? get hakim => _hukumManager.hakim;
  Suit? get trump => _state?.trump;
  int get matchTarget => _scoreManager.matchTarget;

  void addListener(GameEventListener listener) => _listeners.add(listener);
  void removeListener(GameEventListener listener) =>
      _listeners.remove(listener);

  void _emit(GameEvent event) {
    // کپی لیست تا حذف شنوندهٔ همگام خطا نسازد.
    for (final listener in List<GameEventListener>.of(_listeners)) {
      listener.onGameEvent(event);
    }
  }

  // ---------- راه‌اندازی مسابقه ----------

  /// ساخت مسابقهٔ جدید — بازیکن انسانی در جایگاه جنوب.
  void startMatch({
    String humanName = 'شما',
    String teammateName = 'نازنین',
    String opponentWestName = 'آرش',
    String opponentEastName = 'کاوه',
    Seat humanSeat = Seat.south,
  }) {
    final players = <Player>[
      Player(id: 'p_south', name: '', seat: Seat.south, isHuman: true),
      Player(id: 'p_west', name: '', seat: Seat.west, isHuman: false),
      Player(id: 'p_north', name: '', seat: Seat.north, isHuman: false),
      Player(id: 'p_east', name: '', seat: Seat.east, isHuman: false),
    ];
    players[Seat.south.index].name = humanName;
    players[Seat.west.index].name = opponentWestName;
    players[Seat.north.index].name = teammateName;
    players[Seat.east.index].name = opponentEastName;

    final teams = <Team>[
      Team(index: 0, playerIds: const ['p_south', 'p_north']),
      Team(index: 1, playerIds: const ['p_west', 'p_east']),
    ];

    _state = GameState(
      players: players,
      teams: teams,
      phase: GamePhase.hakimDetermination,
      currentTurn: Seat.north,
      matchTarget: _scoreManager.matchTarget,
    );
    _hukumManager = HukumManager();
    _turnManager = null;

    _emit(MatchStartedEvent(
      humanSeat: humanSeat,
      matchTarget: _scoreManager.matchTarget,
    ));
  }

  /// تعیین حاکم اولیه با پخش کارت تا اولین آس.
  HakimDeterminationResult determineHakim() {
    final state = this.state;
    if (state.phase != GamePhase.hakimDetermination) {
      throw StateError('Hakim can only be determined at match start');
    }
    final deck = Deck.standard()..shuffle(_random);
    final result = _hukumManager.determineHakim(deck, Seat.south);
    state.hakim = result.hakim;
    _emit(HakimDeterminedEvent(
      hakim: result.hakim,
      dealtCards: result.dealtCards,
    ));
    return result;
  }

  /// آغاز یک دست (راند) — بر زدن و پخش ۵ کارت اولیه.
  void startRound() {
    final state = this.state;
    final hakim = _hukumManager.hakim;
    if (hakim == null) {
      throw StateError('Hakim must be determined before starting a round');
    }
    // دست را تازه کن (ممکن است دستِ مسابقهٔ جاری باشد).
    for (final player in state.players) {
      player.hand.clear();
    }
    state.trickHistory.clear();
    state.tricksWon[0] = 0;
    state.tricksWon[1] = 0;
    state.currentTrick = null;
    state.trump = null;

    final deck = Deck.standard()..shuffle(_random);
    final steps = _dealManager.dealInitialFive(
      deck: deck,
      players: state.players,
      hakim: hakim,
    );
    _remainingDeck = deck;

    state.phase = GamePhase.awaitingTrumpSelection;
    state.currentTurn = hakim;
    state.hakim = hakim;

    _emit(RoundStartedEvent(roundNumber: state.roundNumber, hakim: hakim));
    _emit(InitialDealEvent(steps: steps));
    _emit(TrumpSelectionRequestedEvent(
      hakim: hakim,
      isHuman: state.playerAt(hakim).isHuman,
      previewCards: List<PlayingCard>.of(state.playerAt(hakim).hand),
    ));
  }

  Deck? _remainingDeck;

  // ---------- انتخاب حکم ----------

  /// حاکم خال حکم را انتخاب می‌کند؛ سپس باقی کارت‌ها (۴+۴) پخش می‌شوند.
  void selectTrump(Seat seat, Suit suit) {
    final state = this.state;
    if (state.phase != GamePhase.awaitingTrumpSelection) {
      throw StateError('Not waiting for trump selection (phase=${state.phase})');
    }
    if (seat != state.hakim) {
      throw StateError('Only the hakim (${state.hakim}) can select trump');
    }
    state.trump = suit;
    _emit(TrumpSelectedEvent(by: seat, trump: suit));

    state.phase = GamePhase.dealing;
    final deck = _remainingDeck ?? _reconstructRemainingDeck();
    final batches = _dealManager.dealRemaining(
      deck: deck,
      players: state.players,
      hakim: seat,
    );
    for (var i = 0; i < batches.length; i++) {
      _emit(DealBatchEvent(batchIndex: i, steps: batches[i]));
    }
    _remainingDeck = null;

    for (final player in state.players) {
      player.sortHand(suit);
    }

    state.phase = GamePhase.playing;
    _turnManager = TurnManager(leader: seat);
    state.currentTurn = seat;
    _emit(const DealCompletedEvent());
    _emitTurnChanged(isTrickLeader: true);
  }

  /// بازسازی دستهٔ باقی‌مانده پس از بازیابی Save مربوط به فازِ
  /// انتخاب حکم: کارت‌هایی که هنوز دیده نشده‌اند = ۵۲ منهای دست بازیکنان.
  /// چون این کارت‌ها پیش از سیو برای هیچ‌کس مکشوف نبوده‌اند، بر زدنِ
  /// دوبارهٔ آن‌ها از نظر منطق بازی معادلِ توزیع اصلی است.
  Deck _reconstructRemainingDeck() {
    final state = this.state;
    final dealt = <PlayingCard>{
      for (final p in state.players) ...p.hand,
      ...state.playedCards,
    };
    final remaining = Deck.standard()
        .cards
        .where((c) => !dealt.contains(c))
        .toList();
    final deck = Deck.fromCards(remaining)..shuffle(_random);
    return deck;
  }

  // ---------- بازی کارت ----------

  void _emitTurnChanged({bool isTrickLeader = false}) {
    final state = this.state;
    final seat = state.currentTurn;
    final player = state.playerAt(seat);
    // در ابتدای دور Trick هنوز ساخته نشده — با دورِ خالیِ موقت حساب می‌کنیم.
    final trick = state.currentTrick ?? Trick(leaderSeat: seat);
    _emit(TurnChangedEvent(
      seat: seat,
      isHuman: player.isHuman,
      legalPlays: GameRules.legalPlays(player.hand, trick),
      isTrickLeader: isTrickLeader,
    ));
  }

  /// بازیِ یک کارت توسط بازیکن [seat].
  ///
  /// برمی‌گرداند رویداد TrickCompleted اگر با این کارت دور تمام شده باشد،
  /// تا controller بداند چه رویدادهایی روی صف انیمیشن می‌آید.
  void playCard(Seat seat, PlayingCard card) {
    final state = this.state;
    if (state.phase != GamePhase.playing) {
      throw StateError('Not in playing phase (phase=${state.phase})');
    }
    if (seat != state.currentTurn) {
      throw StateError('Not $seat\'s turn (current=${state.currentTurn})');
    }
    final player = state.playerAt(seat);
    final trick = state.currentTrick ??= Trick(leaderSeat: seat);
    if (!GameRules.isLegalPlay(card, player.hand, trick)) {
      throw ArgumentError(
          'Illegal play: ${card.id} by $seat (led=${trick.ledSuit})');
    }

    player.removeCard(card);
    trick.add(PlayedCard(seat: seat, card: card));

    _emit(CardPlayedEvent(
      seat: seat,
      card: card,
      trick: trick,
      remainingInHand: player.handCount,
    ));

    if (!trick.isComplete) {
      state.currentTurn = _turnManager!.advance();
      _emitTurnChanged();
      return;
    }

    // دور کامل شد — برنده را پیدا کن.
    final winner = GameRules.trickWinner(trick, state.trump!);
    state.tricksWon[winner.seat.teamIndex]++;
    state.trickHistory.add(trick);
    state.currentTrick = null;

    _emit(TrickCompletedEvent(
      trick: trick,
      winnerSeat: winner.seat,
      tricksWon: List<int>.of(state.tricksWon),
    ));

    if (state.isRoundComplete) {
      _settleRound();
      return;
    }

    // برنده، دورِ بعد را شروع می‌کند.
    state.currentTurn = winner.seat;
    _turnManager!.setCurrent(winner.seat);
    _emitTurnChanged(isTrickLeader: true);
  }

  void _settleRound() {
    final state = this.state;
    state.phase = GamePhase.roundEnd;

    final result = _scoreManager.settleRound(
      tricksTeam0: state.tricksWon[0],
      tricksTeam1: state.tricksWon[1],
      hakimTeamIndex: state.hakim!.teamIndex,
    );
    final matchOver =
        _scoreManager.applyAndCheckMatchEnd(result, state.teams);

    final nextHakim = _hukumManager.rotateAfterRound(
      winnerTeamIndex: result.winnerTeamIndex,
    );
    state.hakim = nextHakim;
    state.roundNumber++;

    final scores = <int>[state.teams[0].matchScore, state.teams[1].matchScore];

    _emit(RoundEndedEvent(
      result: result,
      tricksWon: List<int>.of(state.tricksWon),
      matchScores: scores,
      nextHakim: nextHakim,
    ));

    if (matchOver) {
      state.phase = GamePhase.matchEnd;
      _emit(MatchEndedEvent(
        winnerTeamIndex: _scoreManager.matchWinnerIndex(state.teams)!,
        matchScores: scores,
      ));
    }
  }

  // ---------- بازیابی بازی ذخیره‌شده ----------

  /// بارگذاری مستقیم GameState (برای ادامهٔ بازی ذخیره‌شده).
  ///
  /// رویدادی emit نمی‌کند؛ controller رابط را از روی state بازسازی می‌کند.
  void restoreState(GameState restored) {
    _state = restored;
    _hukumManager = HukumManager()..setHakim(restored.hakim ?? Seat.south);
    _turnManager = TurnManager(leader: restored.currentTurn);
    _remainingDeck = null; // کارت‌ها از قبل در دست بازیکنان هستند.
  }
}
