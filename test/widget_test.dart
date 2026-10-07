import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelem/main.dart';
import 'package:shelem/model/card.dart';
import 'package:shelem/state/game_controller.dart';
import 'package:shelem/state/settings.dart';
import 'package:shelem/ui/screens/game_screen.dart';
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
    expect(find.text('حالت دو نفره'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('مرحلهٔ خواندن (حراج)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('مرحلهٔ خواندن (حراج)'), findsOneWidget);
  });

  testWidgets('صفحهٔ تنظیمات باز می‌شود و سطح حریف را نشان می‌دهد',
      (WidgetTester tester) async {
    await tester.pumpWidget(ShelemApp(settings: AppSettings()));
    await tester.pump();
    await tester.tap(find.text('تنظیمات'));
    await tester.pumpAndSettle();
    expect(find.text('تعداد بازیکنان'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('سطح حریف‌ها'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('سطح حریف‌ها'), findsOneWidget);
    expect(find.text('استاد'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('زمین بازی'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
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

  testWidgets('میز بازی روی صفحهٔ گوشی بدون سرریز چیده می‌شود',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final GameController controller =
        GameController(settings: AppSettings(), random: Random(5))..newGame();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('fa'),
        supportedLocales: const <Locale>[Locale('fa'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (BuildContext context, Widget? child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: GameScreen(controller: controller),
      ),
    );

    // چند نوبتِ ربات را جلو می‌بریم تا مراحل مختلف رسم شوند.
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
    }

    expect(find.byType(GameScreen), findsOneWidget);

    controller.quitToMenu();
    await tester.pump();
    controller.dispose();
  });

  testWidgets('میزِ دو نفره بدون سرریز چیده می‌شود',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final AppSettings settings = AppSettings();
    settings.rules = settings.rulesWith(players: 2);
    final GameController controller =
        GameController(settings: settings, random: Random(5))..newGame();
    expect(controller.engine!.seats, 2);
    expect(controller.engine!.stock.length, 24);
    expect(controller.teamName(0), 'شما');
    expect(controller.teamName(1), 'حریف');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('fa'),
        supportedLocales: const <Locale>[Locale('fa'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (BuildContext context, Widget? child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: GameScreen(controller: controller),
      ),
    );

    // چند نوبتِ ربات را جلو می‌بریم تا مراحل مختلف رسم شوند.
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
    }

    expect(find.byType(GameScreen), findsOneWidget);

    controller.quitToMenu();
    await tester.pump();
    controller.dispose();
  });
}
