import 'dart:math';

import 'package:hokm/ai/players/ai_player.dart';
import 'package:hokm/game_engine/engine_events.dart';
import 'package:hokm/game_engine/game_event_listener.dart';
import 'package:hokm/game_engine/hokm_engine.dart';
import 'package:hokm/game_engine/state/game_enums.dart';

/// شنونده‌ای که همهٔ رویدادها را جمع می‌کند (برای assert روی جریان بازی).
class EventRecorder extends GameEventListener {
  final List<GameEvent> events = <GameEvent>[];

  @override
  void onGameEvent(GameEvent event) => events.add(event);

  T? lastOfType<T extends GameEvent>() {
    for (var i = events.length - 1; i >= 0; i--) {
      final e = events[i];
      if (e is T) return e;
    }
    return null;
  }

  List<T> allOfType<T extends GameEvent>() =>
      events.whereType<T>().toList();

  void clear() => events.clear();
}

/// رانندهٔ تست — یک مسابقهٔ کامل AI-علیه-AI را بدون UI اجرا می‌کند.
///
/// هر چهار جایگاه توسط AiPlayer اداره می‌شوند؛ انسانِ واقعی‌ای در کار نیست.
/// برای هر seat یک سطح دشواری جدا می‌توان داد.
class AiMatchDriver {
  AiMatchDriver({
    int seed = 42,
    Map<Seat, AiDifficulty>? difficulties,
    int matchTarget = 7,
  }) : engine = HokmEngine(
          random: Random(seed),
          matchTarget: matchTarget,
        ) {
    final diffs = difficulties ??
        const {
          Seat.south: AiDifficulty.hard,
          Seat.west: AiDifficulty.hard,
          Seat.north: AiDifficulty.hard,
          Seat.east: AiDifficulty.hard,
        };
    players = {
      for (final seat in Seat.values)
        seat: AiPlayer(
          seat: seat,
          difficulty: diffs[seat] ?? AiDifficulty.normal,
          random: Random(seed ^ (seat.index * 7919)),
        ),
    };
    recorder = EventRecorder();
    engine.addListener(recorder);
  }

  final HokmEngine engine;
  late final Map<Seat, AiPlayer> players;
  late final EventRecorder recorder;

  /// اجرای یک دست کامل (تا پایان ۱۳ دور). برمی‌گرداند تعداد دورهای بردهٔ تیم‌ها.
  List<int> playOneRound() {
    engine.startRound();
    final hakim = engine.state.hakim!;
    final trump = players[hakim]!.selectTrump(engine.state);
    engine.selectTrump(hakim, trump);

    int safety = 0;
    while (engine.state.phase == GamePhase.playing) {
      safety++;
      if (safety > 60) {
        throw StateError('Round did not finish — possible infinite loop');
      }
      final seat = engine.state.currentTurn;
      final card = players[seat]!.chooseCard(engine.state);
      engine.playCard(seat, card);
    }
    return List<int>.of(engine.state.tricksWon);
  }

  /// اجرای مسابقهٔ کامل تا پایان. برمی‌گرداند تعداد دست‌های بازی‌شده.
  int playFullMatch({int maxRounds = 50}) {
    engine.startMatch();
    engine.determineHakim();
    var rounds = 0;
    while (engine.state.phase != GamePhase.matchEnd) {
      rounds++;
      if (rounds > maxRounds) {
        throw StateError('Match did not end within $maxRounds rounds');
      }
      playOneRound();
    }
    return rounds;
  }
}
