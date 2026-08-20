import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../ai/players/ai_player.dart';
import '../audio/sound_manager.dart';
import '../core/app_strings.dart';
import '../game_engine/engine_events.dart';
import '../game_engine/game_event_listener.dart';
import '../game_engine/hokm_engine.dart';
import '../game_engine/models/playing_card.dart';
import '../game_engine/models/suit.dart';
import '../game_engine/rules/game_rules.dart';
import '../game_engine/scoring/score_manager.dart';
import '../game_engine/state/game_enums.dart';
import '../game_engine/state/game_state.dart';
import '../storage/save_manager.dart';
import '../storage/settings_repository.dart';
import 'hokm_game.dart';

/// کنترلر اصلی — واسط میان موتور (منطق خالص)، AI، صحنهٔ Flame،
/// صدا و ماندگاری. هیچ قانون بازی‌ای اینجا پیاده نمی‌شود؛ فقط ارکستراسیون.
class GameController extends ChangeNotifier implements GameEventListener {
  GameController({
    required SettingsController settings,
    required SaveManager saveManager,
    SoundManager? sound,
  })  : _settings = settings,
        _saveManager = saveManager,
        _sound = sound ?? SoundManager.instance {
    // نمونهٔ اولیه تا getterهای HUD پیش از شروع مسابقه امن بمانند.
    _engine = HokmEngine();
  }

  final SettingsController _settings;
  final SaveManager _saveManager;
  final SoundManager _sound;

  late HokmEngine _engine;
  Map<Seat, AiPlayer> _aiPlayers = {};
  HokmGame? _game;

  static const Seat humanSeat = Seat.south;

  final Queue<GameEvent> _eventQueue = Queue<GameEvent>();
  bool _pumping = false;

  /// شمارندهٔ نشست — تغییر آن همهٔ کارهای زمان‌بندی‌شدهٔ قدیمی را باطل می‌کند.
  int _session = 0;

  // ---------- وضعیت نمایشی برای HUD ----------

  /// بنر کوتاه روی صفحه (مثلاً «حاکم: شما»).
  String? banner;
  bool showTrumpPicker = false;
  List<PlayingCard> trumpPreview = const [];
  bool showRoundResult = false;
  RoundResult? roundResult;
  bool showMatchResult = false;
  int matchWinnerTeam = -1;
  bool inputLocked = true; // قفل ورودی در حین انیمیشن

  /// تاریخچهٔ دست‌های این مسابقه (برای جدول امتیازات) — از دید تیم انسان.
  final List<RoundRecord> roundHistory = [];

  /// نمای فقط‌خواندنی تاریخچهٔ دست‌ها برای UI.
  List<RoundRecord> get roundRecords => List.unmodifiable(roundHistory);

  // ---------- دسترسی به وضعیت موتور برای HUD ----------

  bool get hasMatch => _engine.isMatchStarted;
  GameState get state => _engine.state;
  Suit? get trump => hasMatch ? state.trump : null;
  Seat? get hakim => hasMatch ? state.hakim : null;
  Seat? get currentTurn => hasMatch ? state.currentTurn : null;
  GamePhase? get phase => hasMatch ? state.phase : null;
  int get scoreUs =>
      hasMatch ? state.teams[humanSeat.teamIndex].matchScore : 0;
  int get scoreThem =>
      hasMatch ? state.teams[1 - humanSeat.teamIndex].matchScore : 0;
  int get tricksUs => hasMatch ? state.tricksWon[humanSeat.teamIndex] : 0;
  int get tricksThem =>
      hasMatch ? state.tricksWon[1 - humanSeat.teamIndex] : 0;
  bool get isHumanTurn =>
      hasMatch &&
      state.phase == GamePhase.playing &&
      state.currentTurn == humanSeat &&
      !inputLocked;
  int get matchTarget => _engine.matchTarget;
  String playerName(Seat seat) => state.playerAt(seat).name;

  Duration _dur(int ms) =>
      Duration(milliseconds: (ms * _speedFactor()).round());

  double _speedFactor() => _settings.model.animationSpeed.multiplier;

  // ================================================================
  // اتصال صحنه
  // ================================================================

  void attachGame(HokmGame game) {
    _game = game;
    game.onHumanCardTapped = _onHumanCardTapped;
    game.applySettings(_settings.model);
  }

  // ================================================================
  // جریان مسابقه
  // ================================================================

  /// شروع مسابقهٔ نو.
  Future<void> startNewMatch() async {
    _session++;
    final session = _session;
    _eventQueue.clear();
    _pumping = false;
    _awaitingHuman = false;
    roundHistory.clear();
    _resetHud();

    _engine = HokmEngine(matchTarget: ScoreManager.defaultMatchTarget);
    _engine.addListener(this);
    _buildAiPlayers();

    await _saveManager.clear();
    _engine.startMatch();
    if (session != _session) return;
    _engine.determineHakim();
    _pump();
  }

  /// ادامهٔ مسابقهٔ ذخیره‌شده.
  Future<void> resumeMatch(SavedMatch saved) async {
    _session++;
    _eventQueue.clear();
    _pumping = false;
    _awaitingHuman = false;
    roundHistory.clear();
    _resetHud();

    _engine = HokmEngine(matchTarget: saved.state.matchTarget);
    _engine.addListener(this);
    _buildAiPlayers(difficulty: saved.difficulty);
    _engine.restoreState(saved.state.clone());

    final game = _game;
    if (game != null) {
      game.setupPlayers(
        names: {for (final p in state.players) p.seat: p.name},
        humanSeat: humanSeat,
        hakim: state.hakim,
      );
      game.rebuildFromState(
        hands: {for (final p in state.players) p.seat: List.of(p.hand)},
        centerCards: {
          if (state.currentTrick != null)
            for (final p in state.currentTrick!.cards) p.seat: p.card,
        },
        tricksWonByTeam: {0: state.tricksWon[0], 1: state.tricksWon[1]},
      );
    }
    notifyListeners();

    // از همان نقطه ادامه بده.
    if (state.phase == GamePhase.awaitingTrumpSelection) {
      _beginTrumpSelection(state.hakim!);
    } else if (state.phase == GamePhase.playing) {
      _kickOffTurn(state.currentTurn);
    } else if (state.phase == GamePhase.roundEnd) {
      // ذخیره در لحظهٔ پایان دست → دست بعدی را شروع کن.
      _engine.startRound();
      _pump();
    }
  }

  void _buildAiPlayers({AiDifficulty? difficulty}) {
    final level = difficulty ?? _settings.model.aiDifficulty;
    _aiPlayers = {
      for (final seat in Seat.values)
        if (seat != humanSeat) seat: AiPlayer(seat: seat, difficulty: level),
    };
  }

  void _resetHud() {
    banner = null;
    showTrumpPicker = false;
    trumpPreview = const [];
    showRoundResult = false;
    roundResult = null;
    showMatchResult = false;
    matchWinnerTeam = -1;
    inputLocked = true;
    notifyListeners();
  }

  // ================================================================
  // پردازش صف رویدادها — قلب ارکستراسیون
  // ================================================================

  @override
  void onGameEvent(GameEvent event) {
    _eventQueue.add(event);
    _pump();
  }

  void _pump() {
    if (_pumping) return;
    _pumping = true;
    unawaited(_drainQueue());
  }

  Future<void> _drainQueue() async {
    final session = _session;
    try {
      while (_eventQueue.isNotEmpty) {
        if (session != _session) return;
        final event = _eventQueue.removeFirst();
        final shouldContinue = await _handleEvent(event, session);
        if (!shouldContinue) return; // منتظر ورودی کاربر مانده‌ایم
        if (session != _session) return;
      }
    } finally {
      _pumping = false;
    }
    // ممکن است حین پردازش رویداد جدید آمده باشد.
    if (_eventQueue.isNotEmpty) _pump();
  }

  /// برمی‌گرداند false اگر جریان باید منتظر ورودی انسان بماند.
  Future<bool> _handleEvent(GameEvent event, int session) async {
    final game = _game;
    switch (event) {
      case MatchStartedEvent():
        return true;

      case HakimDeterminedEvent():
        if (game != null) {
          game.setupPlayers(
            names: {for (final p in state.players) p.seat: p.name},
            humanSeat: humanSeat,
            hakim: event.hakim,
          );
          await game.animateHakimDetermination(event.dealtCards);
        }
        if (session != _session) return false;
        _showBanner(
          event.hakim == humanSeat
              ? '${AppStrings.hakimLabel}: ${AppStrings.you}'
              : '${AppStrings.hakimLabel}: ${playerName(event.hakim)}',
          holdMs: 1400,
        );
        _engine.startRound();
        return true;

      case RoundStartedEvent():
        game?.setHakimBadge(event.hakim);
        if (game != null) {
          _sound.shuffle();
          await game.animateShuffle();
        }
        return true;

      case InitialDealEvent():
        if (game != null) {
          _sound.deal();
          await game.animateDealBatch(event.steps,
              faceUpSeats: const {Seat.south});
          await game.finalizeHands();
        }
        notifyListeners();
        return true;

      case TrumpSelectionRequestedEvent():
        _beginTrumpSelection(event.hakim);
        return !state.playerAt(event.hakim).isHuman; // انسان: توقف پمپ

      case TrumpSelectedEvent():
        showTrumpPicker = false;
        _sound.hukumSelected();
        _showBanner(
            '${AppStrings.trumpLabel}: ${event.trump.faName}', holdMs: 1200);
        notifyListeners();
        return true;

      case DealBatchEvent():
        if (game != null) {
          _sound.deal();
          await game.animateDealBatch(event.steps,
              faceUpSeats: const {Seat.south});
        }
        _save();
        return true;

      case DealCompletedEvent():
        if (game != null) {
          await game.finalizeHands();
          await game.syncHumanHandOrder(
              List.of(state.playerAt(humanSeat).hand));
        }
        _save();
        return true;

      case TurnChangedEvent():
        return _handleTurnEvent(event, session);

      case CardPlayedEvent():
        if (game != null) await game.animatePlayCard(event.seat, event.card);
        _sound.cardPlace();
        notifyListeners();
        return true;

      case TrickCompletedEvent():
        if (game != null) {
          _sound.trickWin();
          await game.animateCollectTrick(
            event.winnerSeat,
            event.winnerSeat.teamIndex,
            isWin: event.winnerSeat.teamIndex == humanSeat.teamIndex,
          );
        }
        _save();
        notifyListeners();
        return true;

      case RoundEndedEvent():
        roundResult = event.result;
        // ثبت در جدول امتیازات — امتیاز مسابقه در موتور پیش از انتشار
        // این رویداد اعمال شده، پس scoreUs/scoreThem به‌روز است.
        final weWonRound = event.result.winnerTeamIndex == humanSeat.teamIndex;
        roundHistory.add(RoundRecord(
          roundNumber: state.roundNumber,
          tricksUs: weWonRound
              ? event.result.winnerTricks
              : event.result.loserTricks,
          tricksThem: weWonRound
              ? event.result.loserTricks
              : event.result.winnerTricks,
          totalUs: scoreUs,
          totalThem: scoreThem,
          winnerIsUs: weWonRound,
          pointsAwarded: event.result.pointsAwarded,
          isKoot: event.result.isKoot,
          isHakimKoot: event.result.isHakimKoot,
        ));
        // اگر مسابقه هم تمام شده، دیالوگ دست را نشان نده —
        // رویداد MatchEnded همان‌جا در صف است و نتیجهٔ نهایی نمایش داده می‌شود.
        final matchEndsNow = _eventQueue.any((e) => e is MatchEndedEvent);
        showRoundResult = !matchEndsNow;
        if (event.result.winnerTeamIndex == humanSeat.teamIndex) {
          _sound.roundWin();
        }
        _save();
        notifyListeners();
        return true;

      case MatchEndedEvent():
        showRoundResult = false;
        roundResult = null;
        showMatchResult = true;
        matchWinnerTeam = event.winnerTeamIndex;
        inputLocked = true;
        if (event.winnerTeamIndex == humanSeat.teamIndex) {
          _sound.matchWin();
        } else {
          _sound.matchLose();
        }
        await _saveManager.clear();
        notifyListeners();
        return true;
    }
  }

  // ---------- نوبت ----------

  Future<bool> _handleTurnEvent(TurnChangedEvent event, int session) async {
    final game = _game;
    inputLocked = true;
    if (event.isHuman) {
      // توقف پمپ تا انتخاب انسان.
      _awaitingHuman = true;
      _humanLegalPlays = event.legalPlays;
      inputLocked = false;
      game?.showTurn(Seat.south);
      game?.setHumanPlayableCards(event.legalPlays, enable: true);
      notifyListeners();
      return false;
    }

    // نوبت AI
    _awaitingHuman = false;
    game?.showTurn(event.seat);
    notifyListeners();

    // ریتم طبیعی تفکر AI
    await Future<void>.delayed(_dur(560));
    if (session != _session) return false;

    final ai = _aiPlayers[event.seat]!;
    final card = ai.chooseCard(state);
    _engine.playCard(event.seat, card);
    return true;
  }

  bool _awaitingHuman = false;
  List<PlayingCard> _humanLegalPlays = const [];

  /// شروع تعیین حکم — انسان یا AI.
  void _beginTrumpSelection(Seat hakimSeat) {
    final isHuman = state.playerAt(hakimSeat).isHuman;
    if (isHuman) {
      showTrumpPicker = true;
      trumpPreview = List.of(state.playerAt(hakimSeat).hand);
      notifyListeners();
    } else {
      _showBanner(AppStrings.hakimChoosingTrump, holdMs: 1300);
      notifyListeners();
      final session = _session;
      unawaited(Future<void>.delayed(_dur(1000), () {
        if (session != _session) return;
        final ai = _aiPlayers[hakimSeat]!;
        final suit = ai.selectTrump(state);
        _engine.selectTrump(hakimSeat, suit);
        _pump();
      }));
    }
  }

  /// انتخاب حکم توسط انسان (از دیالوگ).
  void onHumanTrumpSelected(Suit suit) {
    if (!showTrumpPicker) return;
    showTrumpPicker = false;
    notifyListeners();
    _engine.selectTrump(state.hakim!, suit);
    _pump();
  }

  void _onHumanCardTapped(PlayingCard card) {
    if (!_awaitingHuman || inputLocked) return;
    if (!_humanLegalPlays.contains(card)) return;
    _awaitingHuman = false;
    inputLocked = true;
    _sound.cardPick();
    final game = _game;
    game?.hideTurn();
    game?.setHumanPlayableCards(const [], enable: false);
    _engine.playCard(humanSeat, card);
    notifyListeners();
    _pump();
  }

  /// دنبال کردن بازی پس از بستن دیالوگ نتیجهٔ دست.
  void continueToNextRound() {
    showRoundResult = false;
    roundResult = null;
    notifyListeners();
    _engine.startRound();
    _pump();
  }

  // ---------- ادامهٔ بازی ذخیره → ورود به نوبت ----------

  void _kickOffTurn(Seat seat) {
    // اگر نوبت انسان است، کارت‌های مجاز را فعال کن؛ وگرنه AI را زمان‌بندی کن.
    final isHuman = state.playerAt(seat).isHuman;
    if (isHuman) {
      _handleTurnEvent(
          TurnChangedEvent(
            seat: seat,
            isHuman: true,
            legalPlays: state.currentTrick == null
                ? List.of(state.playerAt(seat).hand)
                : GameRules.legalPlays(
                    state.playerAt(seat).hand, state.currentTrick!),
          ),
          _session);
    } else {
      _handleTurnEvent(
        TurnChangedEvent(seat: seat, isHuman: false, legalPlays: const []),
        _session,
      ).then((cont) {
        if (cont) _pump();
      });
    }
  }

  // ---------- بنر ----------

  void _showBanner(String text, {int holdMs = 1200}) {
    banner = text;
    notifyListeners();
    final session = _session;
    final textAtSet = text;
    unawaited(Future<void>.delayed(_dur(holdMs), () {
      if (session != _session) return;
      if (banner == textAtSet) {
        banner = null;
        notifyListeners();
      }
    }));
  }

  void _save() {
    if (!_engine.isMatchStarted) return;
    if (state.phase == GamePhase.matchEnd) return;
    unawaited(_saveManager.saveMatch(SavedMatch(
      state: state.clone(),
      difficulty: _settings.model.aiDifficulty,
      savedAtMillis: DateTime.now().millisecondsSinceEpoch,
      humanSeat: humanSeat,
    )));
  }

  /// ذخیرهٔ دستی (خروج از صفحهٔ بازی).
  void saveNow() => _save();

  @override
  void dispose() {
    _session++;
    _eventQueue.clear();
    super.dispose();
  }
}
