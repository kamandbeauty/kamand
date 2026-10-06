import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelem/main.dart';
import 'package:shelem/model/card.dart';
import 'package:shelem/state/settings.dart';
import 'package:shelem/ui/theme.dart';
import 'package:shelem/ui/widgets/card_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('منوی اصلی با گزینه‌های اصلی نمایش داده می‌شود',
      (WidgetTester tester) async {
    await tester.pumpWidget(ShelemApp(settings: AppSettings()));
    await tester.pump();

    expect(find.text('شلم'), findsOneWidget);
    expect(find.text('بازی جدید'), findsOneWidget);
    expect(find.text('تنظیمات'), findsOneWidget);
    expect(find.text('قوانین بازی'), findsOneWidget);
    expect(find.text('ادامهٔ بازی قبلی'), findsNothing);
  });

  testWidgets('صفحهٔ قوانین باز می‌شود', (WidgetTester tester) async {
    await tester.pumpWidget(ShelemApp(settings: AppSettings()));
    await tester.pump();
    await tester.tap(find.text('قوانین بازی'));
    await tester.pumpAndSettle();
    expect(find.text('قوانین شلم'), findsOneWidget);
    expect(find.text('مرحلهٔ خواندن (حراج)'), findsOneWidget);
  });

  testWidgets('صفحهٔ تنظیمات باز می‌شود و سطح حریف را نشان می‌دهد',
      (WidgetTester tester) async {
    await tester.pumpWidget(ShelemApp(settings: AppSettings()));
    await tester.pump();
    await tester.tap(find.text('تنظیمات'));
    await tester.pumpAndSettle();
    expect(find.text('سطح حریف‌ها'), findsOneWidget);
    expect(find.text('استاد'), findsOneWidget);
    expect(find.text('زمین بازی'), findsOneWidget);
  });

  testWidgets('کارت با نماد و برچسب درست رسم می‌شود',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: CardView(card: PlayingCard(Suit.hearts, 14), width: 60),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('A'), findsWidgets);
    expect(find.byType(CardView), findsOneWidget);
  });
}
