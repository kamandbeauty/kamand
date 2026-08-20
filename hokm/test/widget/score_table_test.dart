import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hokm/core/persian_utils.dart';
import 'package:hokm/game_engine/scoring/score_manager.dart';
import 'package:hokm/screens/game/widgets/score_table.dart';

void main() {
  RoundRecord rec({
    required int round,
    required int us,
    required int them,
    required int totalUs,
    required int totalThem,
    required bool weWon,
    int points = 1,
    bool koot = false,
    bool hakimKoot = false,
  }) =>
      RoundRecord(
        roundNumber: round,
        tricksUs: us,
        tricksThem: them,
        totalUs: totalUs,
        totalThem: totalThem,
        winnerIsUs: weWon,
        pointsAwarded: points,
        isKoot: koot,
        isHakimKoot: hakimKoot,
      );

  testWidgets('جدول امتیازات: سرستون‌ها و ردیف‌ها با ارقام فارسی رندر می‌شوند',
      (tester) async {
    final records = [
      rec(
          round: 1,
          us: 7,
          them: 4,
          totalUs: 2,
          totalThem: 0,
          weWon: true,
          points: 2,
          koot: true),
      rec(
          round: 2,
          us: 5,
          them: 7,
          totalUs: 2,
          totalThem: 1,
          weWon: false),
      rec(
          round: 3,
          us: 13,
          them: 0,
          totalUs: 5,
          totalThem: 1,
          weWon: true,
          points: 3,
          hakimKoot: true),
    ];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          home: Scaffold(body: ScoreTable(records: records)),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // سرستون‌ها
    expect(find.text('دست'), findsOneWidget);
    expect(find.text('قانون'), findsOneWidget);
    // شمارهٔ دست‌ها به ترتیب فارسی
    expect(find.text('اول'), findsOneWidget);
    expect(find.text('دوم'), findsOneWidget);
    expect(find.text('سوم'), findsOneWidget);
    // قوانین ویژه
    expect(find.text('کوت'), findsOneWidget);
    expect(find.text('حاکم‌کوت'), findsOneWidget);
    // مجموع نهایی ارقام فارسی
    expect(find.text('۵'), findsWidgets);
    expect(find.text('۱'), findsWidgets);
  });

  test('persianOrdinal', () {
    expect(persianOrdinal(1), 'اول');
    expect(persianOrdinal(2), 'دوم');
    expect(persianOrdinal(7), 'هفتم');
    expect(persianOrdinal(13), 'سیزدهم');
    expect(persianOrdinal(21), '۲۱م'); // خارج از بازهٔ واژه‌ها
  });

  test('RoundRecord json round-trip', () {
    final r = RoundRecord(
      roundNumber: 4,
      tricksUs: 7,
      tricksThem: 6,
      totalUs: 3,
      totalThem: 4,
      winnerIsUs: false,
      pointsAwarded: 3,
      isKoot: true,
      isHakimKoot: true,
    );
    final restored = RoundRecord.fromJson(r.toJson());
    expect(restored.roundNumber, 4);
    expect(restored.tricksUs, 7);
    expect(restored.tricksThem, 6);
    expect(restored.totalUs, 3);
    expect(restored.totalThem, 4);
    expect(restored.winnerIsUs, isFalse);
    expect(restored.pointsAwarded, 3);
    expect(restored.isKoot, isTrue);
    expect(restored.isHakimKoot, isTrue);
    expect(restored.ruleLabel, 'حاکم‌کوت');
  });

  test('RoundRecord rule labels', () {
    RoundRecord label({bool koot = false, bool hk = false}) => RoundRecord(
          roundNumber: 1,
          tricksUs: 7,
          tricksThem: koot ? 0 : 6,
          totalUs: 1,
          totalThem: 0,
          winnerIsUs: true,
          pointsAwarded: koot ? (hk ? 3 : 2) : 1,
          isKoot: koot,
          isHakimKoot: hk,
        );
    expect(label().ruleLabel, '—');
    expect(label(koot: true).ruleLabel, 'کوت');
    expect(label(koot: true, hk: true).ruleLabel, 'حاکم‌کوت');
  });
}
