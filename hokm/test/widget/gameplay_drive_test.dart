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

/// تست رانندگی کامل — مسیر تعامل انسان از روی GameWidget را واقعاً طی
/// می‌کند (انتخاب حکم + لمس کارت) و بخش‌هایی از یک مسابقهٔ واقعی را با
/// فریم‌های واقعی Flame پیش می‌برد. هر استثنای فریم‌ورک = شکست تست.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('A match can be played via real taps without framework errors',
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
    // صحنه ساخته شود و اولین فریم‌ها گذر بکند.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(game.isSceneReady, isTrue);

    await controller.startNewMatch();

    var humanPlays = 0;
    var trumpPicked = false;
    var roundsContinued = 0;

    for (var i = 0; i < 500; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      final error = tester.takeException();
      if (error != null) {
        fail('Framework error during driven gameplay:\n$error');
      }

      if (!controller.hasMatch) break;

      // ۱) اگر انسان حاکم شد، حکم را انتخاب کن.
      if (controller.showTrumpPicker) {
        controller.onHumanTrumpSelected(Suit.values[i % Suit.values.length]);
        trumpPicked = true;
        continue;
      }

      // ۲) پایان دست → رفتن به دست بعدی (چند بار، نه بی‌نهایت).
      if (controller.showRoundResult) {
        if (++roundsContinued > 2) break;
        controller.continueToNextRound();
        continue;
      }

      // ۳) پایان مسابقه → پایان تست با موفقیت.
      if (controller.showMatchResult) break;

      // ۴) نوبت انسان → یک کارت مجاز را با لمس واقعی بازی کن.
      if (controller.isHumanTurn &&
          controller.state.phase == GamePhase.playing) {
        final tapped = await _tapFirstLegalCard(tester, game, controller);
        if (tapped) humanPlays++;
        continue;
      }
    }

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // پیشروی واقعی مسابقه: حداقل چند دور کامل شده باشد.
    final tricksDone = controller.hasMatch
        ? controller.state.tricksWon[0] + controller.state.tricksWon[1]
        : 0;
    expect(
      tricksDone,
      greaterThan(0),
      reason: 'game did not advance: trumpPicked=$trumpPicked '
          'humanPlays=$humanPlays',
    );

    // تخلیهٔ تمیز: dispose باعث خنثی‌شدن تایمرهای زمان‌بندی‌شده می‌شود.
    controller.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));
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
