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

/// پمپِ یک فریم + اطمینان از جاری‌بودنِ زمانِ حلقهٔ بازی.
///
/// در برخی نسخه‌های تازهٔ Flutter (مثل ۳.۴۷)، در محیطِ تست یا چرخهٔ عمرِ
/// اپ به‌صورت paused/hidden تحویل داده می‌شود یا GameLoopِ Flame به تیکر
/// واقعی وصل نمی‌شود؛ نتیجه تیک‌نخوردنِ بازی انجامد و انیمیشن‌ها فریز
/// می‌شوند. این کمکی بعد از پمپِ واقعیِ ویجت‌ها بررسی می‌کند که تیک رسیده
/// باشد؛ در غیر این صورت زمان را دستی جلو می‌برد تا رفتار تست روی همهٔ
/// نسخه‌های SDK یکسان بماند. روی دستگاه واقعی این مسیر هرگز فعال نمی‌شود.
Future<void> _pumpGameFrame(
  WidgetTester tester,
  HokmGame game,
  Duration duration,
) async {
  if (game.paused) {
    // محیط تست ممکن است چرخهٔ عمر را paused/hidden تحویل دهد؛ در تست
    // می‌خواهیم بازی همیشه فعال باشد.
    game.resumeEngine();
  }
  final ticksBefore = game.debugUpdateTickCount;
  await tester.pump(duration);
  if (game.debugUpdateTickCount == ticksBefore) {
    // GameLoopِ Flame در این هارنس تیک نمی‌زند — فقط صف‌های حرکتِ کارت‌ها
    // را جلو می‌بریم. آگاهانه updateTree را صدا نمی‌زنیم: صدازدنِ دستیِ آن
    // می‌تواند با افزودن/حذف/تغییرِ اولویتِ کامپوننت‌ها در میانهٔ پیمایش
    // تداخل کند (ConcurrentModificationError در FlameGame.updateTree).
    game.stepMotionsManually(
        duration.inMicroseconds / Duration.microsecondsPerSecond);
  }
}

/// تست رانندگی کامل — بخش‌هایی از یک مسابقهٔ واقعی را با فریم‌های واقعی
/// Flame و با لمس واقعی کارت‌های انسان پیش می‌برد. هر استثنای فریم‌ورک
/// یا عدم پیشروی مسابقه = شکست تست.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Driven match segment completes tricks with real taps',
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
      await _pumpGameFrame(tester, game, const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(game.isSceneReady, isTrue);

    await controller.startNewMatch();

    var humanTaps = 0;
    var trumpPicked = false;
    var roundsContinued = 0;
    var peakTricks = 0;

    for (var i = 0; i < 700; i++) {
      await _pumpGameFrame(tester, game, const Duration(milliseconds: 200));
      final error = tester.takeException();
      if (error != null) {
        fail('Framework error during driven gameplay:\n$error');
      }

      if (!controller.hasMatch) break;

      final nowTricks =
          controller.state.tricksWon[0] + controller.state.tricksWon[1];
      if (nowTricks > peakTricks) peakTricks = nowTricks;

      if (i % 25 == 0) {
        final s = controller.state;
        print('[dbg] i=$i phase=${s.phase} turn=${s.currentTurn} '
            'tricks=${s.tricksWon} peak=$peakTricks '
            'southHand=${s.playerAt(Seat.south).hand.length} '
            'humanTurn=${controller.isHumanTurn} '
            'ticks=${game.debugUpdateTickCount} dt=${game.debugLastDt} '
            'moving=${game.debugMovingCards}');
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
        final tapped = await _tapFirstLegalCard(tester, game, controller);
        if (tapped) humanTaps++;
        continue;
      }
    }

    await _pumpGameFrame(tester, game, const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // حداقل یک دور کامل باید در این بازه جمع‌شده باشد (شمارندهٔ
    // tricksWon دوربه‌دور صفر می‌شود، پس اوج آن را نگه می‌داریم).
    expect(
      peakTricks,
      greaterThan(0),
      reason: 'game did not advance: trumpPicked=$trumpPicked '
          'humanTaps=$humanTaps roundsContinued=$roundsContinued '
          'phase=${controller.phase}',
    );

    controller.dispose();
    await tester.pumpWidget(const SizedBox());
    await _pumpGameFrame(tester, game, const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 6)));

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

/// اولین کارت مجاز دست انسان را با لمس واقعی روی GameWidget بازی می‌کند.
Future<bool> _tapFirstLegalCard(
  WidgetTester tester,
  HokmGame game,
  GameController controller,
) async {
  final hand = controller.state.playerAt(Seat.south).hand;
  if (hand.isEmpty) return false;
  final trick = controller.state.currentTrick;
  final List<PlayingCard> legal = trick == null
      ? List<PlayingCard>.of(hand)
      : GameRules.legalPlays(hand, trick);
  if (legal.isEmpty) return false;

  final zone = game.handZones[Seat.south]!;
  var zoneIndex = -1;
  for (var i = 0; i < zone.length; i++) {
    if (zone[i].card == legal.first) {
      zoneIndex = i;
      break;
    }
  }
  if (zoneIndex < 0) return false;

  final slot = game.layout.humanHandSlot(zoneIndex, zone.length);
  var tapX = slot.position.x;
  if (zoneIndex < zone.length - 1) {
    // نوار قابل‌مشاهدهٔ کارت‌های زیرپوششی سمت چپ آن‌هاست؛ مرکز ممکن است
    // زیر کارت بعدی باشد.
    tapX = slot.position.x -
        game.layout.cardWidth / 2 +
        game.layout.humanStep * 0.4;
  }
  await tester.tapAt(Offset(tapX, slot.position.y));
  await tester.pump(const Duration(milliseconds: 50));
  return true;
}

/// کاوشگر لمس — تشخیص مستقل اینکه خط لولهٔ رویدادهای لمسی Flame
/// (ثبت پویای MultiTapDispatcher پس از سوار شدن کامپوننت) کار می‌کند.
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
