import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hokm/game/game_controller.dart';
import 'package:hokm/game/hokm_game.dart';
import 'package:hokm/game_engine/models/playing_card.dart';
import 'package:hokm/game_engine/models/suit.dart';
import 'package:hokm/game_engine/rules/game_rules.dart';
import 'package:hokm/game_engine/state/game_enums.dart';
import 'package:hokm/storage/save_manager.dart';
import 'package:hokm/storage/settings_model.dart';
import 'package:hokm/storage/settings_repository.dart';

/// تست رانندگی کامل — بخش‌هایی از یک مسابقهٔ واقعی را با فریم‌های واقعی
/// Flame پیش می‌برد. هر استثنای فریم‌ورک = شکست تست.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Driven full-match segment completes tricks without errors',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsController.load();
    await settings.setAnimationSpeed(AnimationSpeed.fast);
    final saveManager = await SaveManager.load();

    final game = HokmGame(settings: settings.model);
    final controller = GameController(
      settings: settings,
      saveManager: saveManager,
    )..attachGame(game);

    await tester.pumpWidget(
      MaterialApp(home: SizedBox.expand(child: GameWidget(game: game))),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(game.isSceneReady, isTrue);

    await controller.startNewMatch();

    var humanCalls = 0;
    var tapCallbackSuccessful = 0;
    var trumpPicked = false;
    var roundsContinued = 0;

    final previousCallback = game.onHumanCardTapped;
    game.onHumanCardTapped = (PlayingCard card) {
      tapCallbackSuccessful++;
      previousCallback?.call(card);
    };

    for (var i = 0; i < 500; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      final error = tester.takeException();
      if (error != null) {
        fail('Framework error during driven gameplay:\n$error');
      }

      if (!controller.hasMatch) break;

      if (i % 10 == 0) {
        final s = controller.state;
        final handsLen =
            s.players.map((p) => '${p.seat.name}:${p.hand.length}').join(' ');
        print('[dbg] i=$i phase=${s.phase} turn=${s.currentTurn} '
            'trickCards=${s.currentTrick?.cards.length} tricks=${s.tricksWon} '
            'hands=[$handsLen] humanTurn=${controller.isHumanTurn} '
            'banner=${controller.banner}');
      }

      if (controller.showTrumpPicker) {
        controller.onHumanTrumpSelected(Suit.values[i % Suit.values.length]);
        trumpPicked = true;
        continue;
      }

      if (controller.showRoundResult) {
        if (++roundsContinued > 2) break;
        controller.continueToNextRound();
        continue;
      }

      if (controller.showMatchResult) break;

      if (controller.isHumanTurn &&
          controller.state.phase == GamePhase.playing) {
        final hand = controller.state.playerAt(Seat.south).hand;
        final trick = controller.state.currentTrick;
        final List<PlayingCard> legal = trick == null
            ? List<PlayingCard>.of(hand)
            : GameRules.legalPlays(hand, trick);
        if (legal.isNotEmpty) {
          humanCalls++;
          game.onHumanCardTapped?.call(legal.first);
        }
        continue;
      }
    }

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    final tricksDone = controller.hasMatch
        ? controller.state.tricksWon[0] + controller.state.tricksWon[1]
        : 0;
    expect(
      tricksDone,
      greaterThan(0),
      reason: 'game did not advance: trumpPicked=$trumpPicked '
          'humanCalls=$humanCalls taps=$tapCallbackSuccessful '
          'phase=${controller.phase}',
    );

    controller.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('tap events reach TapCallbacks components of the scene',
      (tester) async {
    final game = HokmGame(settings: const SettingsModel());
    final probe = _TapProbe()
      ..position = Vector2(400, 300)
      ..size = Vector2.all(80)
      ..anchor = Anchor.center
      ..priority = 1000;
    game.add(probe);

    await tester.pumpWidget(
      MaterialApp(home: SizedBox.expand(child: GameWidget(game: game))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(game.isSceneReady, isTrue);
    // مرکز کاوشگر — باید یک tapDown و یک tapUp بگیرد.
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(probe.downs, 1);
    expect(probe.ups, 1);

    // خارج از کاوشگر — هیچ رویدادی نباید بگیرد.
    await tester.tapAt(const Offset(40, 560));
    await tester.pump(const Duration(milliseconds: 300));
    expect(probe.downs, 1);
    expect(probe.ups, 1);
  });
}

/// کاوشگر لمس — تشخیص مستقل اینکه خط لولهٔ رویدادهای لمسی Flame
/// (ثبت پویای MultiTapDispatcher پس از سوار شدن کامپوننت) در
/// پیکربندی ویجت ما کار می‌کند.
class _TapProbe extends PositionComponent with TapCallbacks {
  var downs = 0;
  var ups = 0;

  @override
  void onTapDown(TapDownEvent event) {
    downs++;
    event.handled = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    ups++;
  }
}

