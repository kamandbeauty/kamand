import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hokm/game/hokm_game.dart';
import 'package:hokm/screens/game/game_screen.dart';
import 'package:hokm/screens/game/widgets/trump_picker.dart';
import 'package:hokm/storage/save_manager.dart';
import 'package:hokm/storage/settings_model.dart';
import 'package:hokm/storage/settings_repository.dart';

/// تست دود (smoke) برای صفحهٔ بازی: اگر در مسیر ساخت/چیدمان/رندر
/// چیزی بشکند — همان چیزی که کاربر به‌صورت «صفحهٔ خاکستری» می‌بیند —
/// این تست در CI قرمز می‌شود و ردپای دقیق خطا را نشان می‌دهد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GameScreen starts and plays without any framework error',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsController.load();
    final saveManager = await SaveManager.load();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        home: GameScreen(settings: settings, saveManager: saveManager),
      ),
    );
    expect(tester.takeException(), isNull);

    // پیش‌برد زمان قلابی برای عبور از تعیین حاکم، بر، پخش و شروع بازی.
    // هر مرحله باید بدون استثنا بماند.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      final error = tester.takeException();
      if (error != null) {
        fail('Framework error while running the game screen:\n$error');
      }

      // اگر حاکم انسان شد، انتخاب حکم را انجام بده تا جریان ادامه یابد.
      final picker = find.byType(TrumpPickerOverlay);
      if (picker.evaluate().isNotEmpty) {
        final buttons = find.descendant(
          of: picker,
          matching: find.byType(InkWell),
        );
        if (buttons.evaluate().isNotEmpty) {
          await tester.tap(buttons.at(1), warnIfMissed: false);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      }
    }

    // جدا کردن صفحه و تخلیهٔ تایمر‌ها تا پایان تمیز شود؛
    // پاسخ‌های زمان‌بندی‌شدهٔ کنترلر پس از dispose خودشان خنثی می‌شوند.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('HokmGame scene builds, resizes and resets without errors',
      (tester) async {
    addTearDown(tester.view.reset);
    final game = HokmGame(settings: const SettingsModel());

    await tester.pumpWidget(
      MaterialApp(home: SizedBox.expand(child: GameWidget(game: game))),
    );
    // کمی رندر بگذار — صحنه حتماً ساخته شده باشد.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(game.isSceneReady, isTrue);

    // تغییر اندازهٔ واقعی (مثل چرخش صفحه) نباید بشکند.
    tester.view.physicalSize = const Size(490, 780);
    tester.view.devicePixelRatio = 1.0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // بازنشانی میز و چند فریم دیگر.
    game.resetTable();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });
}
