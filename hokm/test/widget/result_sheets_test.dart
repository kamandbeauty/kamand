import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hokm/core/app_strings.dart';
import 'package:hokm/core/persian_utils.dart';
import 'package:hokm/game/game_controller.dart';
import 'package:hokm/game_engine/scoring/score_manager.dart';
import 'package:hokm/screens/game/widgets/match_result_sheet.dart';
import 'package:hokm/screens/game/widgets/round_result_sheet.dart';
import 'package:hokm/screens/game/widgets/score_table.dart';
import 'package:hokm/storage/save_manager.dart';
import 'package:hokm/storage/settings_repository.dart';

/// این تست‌ها از «رندرِ سالمِ» برگه‌های پایان دست و پایان مسابقه محافظت
/// می‌کنند — بخش حساسی که گزارش کاربر را دربارهٔ عدم نمایش جدول پایانِ
/// مسابقه پوشش دارد: هر استثنا در build = شکست تست.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFF101010),
            body: Center(child: child),
          ),
        ),
      );

  const sampleRecords = [
    RoundRecord(
      roundNumber: 1,
      tricksUs: 7,
      tricksThem: 6,
      totalUs: 1,
      totalThem: 0,
      winnerIsUs: true,
      pointsAwarded: 1,
      isKoot: false,
      isHakimKoot: false,
    ),
    RoundRecord(
      roundNumber: 2,
      tricksUs: 0,
      tricksThem: 7,
      totalUs: 1,
      totalThem: 3,
      winnerIsUs: false,
      pointsAwarded: 3,
      isKoot: true,
      isHakimKoot: true,
    ),
  ];

  testWidgets('برگهٔ نتیجهٔ مسابقه: قهرمانی، نمره و جدول امتیازات',
      (tester) async {
    await tester.pumpWidget(wrap(MatchResultSheet(
      winnerTeam: 0,
      scoreUs: 7,
      scoreThem: 3,
      records: sampleRecords,
      onPlayAgain: () {},
      onHome: () {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.matchWon), findsOneWidget);
    expect(find.byType(ScoreTable), findsOneWidget);
    // امتیاز نهایی با ارقام فارسی
    expect(find.textContaining(toPersianDigits(7)), findsWidgets);
  });

  testWidgets('برگهٔ نتیجهٔ مسابقه در شکست هم رندر می‌شود', (tester) async {
    await tester.pumpWidget(wrap(MatchResultSheet(
      winnerTeam: 1,
      scoreUs: 2,
      scoreThem: 7,
      onPlayAgain: () {},
      onHome: () {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.matchLost), findsOneWidget);
  });

  testWidgets('برگهٔ نتیجهٔ دست با جدول و دکمهٔ ادامه رندر می‌شود',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsController.load();
    final saveManager = await SaveManager.load();
    final controller = GameController(
      settings: settings,
      saveManager: saveManager,
    );

    var nextTapped = false;
    await tester.pumpWidget(wrap(RoundResultSheet(
      controller: controller,
      result: const RoundResult(
        winnerTeamIndex: 1,
        winnerTricks: 7,
        loserTricks: 0,
        pointsAwarded: 3,
        isKoot: true,
        isHakimKoot: true,
      ),
      onNext: () => nextTapped = true,
      onExit: () {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ScoreTable), findsOneWidget);

    final button = find.byType(ElevatedButton);
    if (button.evaluate().isNotEmpty) {
      await tester.tap(button.first);
      await tester.pump();
      expect(nextTapped, isTrue);
    }

    controller.dispose();
  });
}
