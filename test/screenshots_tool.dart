/// ابزار گرفتنِ تصویر از رابط کاربری (برای بازبینی طراحی).
///
/// این فایل عمداً به `_test.dart` ختم نمی‌شود تا در اجرای معمولیِ
/// `flutter test` شرکت نکند. در CI این‌طور اجرا می‌شود:
///
/// ```sh
/// flutter test --update-goldens test/screenshots_tool.dart
/// ```
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelem/ai/bot.dart';
import 'package:shelem/game/engine.dart';
import 'package:shelem/model/card.dart';
import 'package:shelem/model/enums.dart';
import 'package:shelem/state/game_controller.dart';
import 'package:shelem/state/settings.dart';
import 'package:shelem/ui/screens/game_screen.dart';
import 'package:shelem/ui/theme.dart';
import 'package:shelem/ui/widgets/card_view.dart';

import 'sim_helper.dart';

Future<void> _loadIconFont() async {
  try {
    final FontLoader loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
  } catch (_) {
    // در برخی نسخه‌ها فونت آیکون در باندلِ تست نیست؛ مهم نیست.
  }
}

Future<void> _loadFonts() async {
  for (final String family in <String>['Vazirmatn']) {
    final FontLoader loader = FontLoader(family);
    for (final String f in <String>[
      'assets/fonts/Vazirmatn-Regular.ttf',
      'assets/fonts/Vazirmatn-Medium.ttf',
      'assets/fonts/Vazirmatn-SemiBold.ttf',
      'assets/fonts/Vazirmatn-Bold.ttf',
    ]) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }
}


/// تصویرهای طرحِ ورق و زمینه باید پیش از عکس‌برداری در حافظه باشند.
Future<void> _precache(WidgetTester tester) async {
  const List<String> assets = <String>[
    'assets/cards/court_jack.png',
    'assets/cards/court_queen.png',
    'assets/cards/court_king.png',
    'assets/cards/court_joker.png',
    'assets/images/surfaces/carpet-antique.jpg',
  ];
  final BuildContext context = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    for (final String a in assets) {
      await precacheImage(AssetImage(a), context);
    }
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('fa'),
      supportedLocales: const <Locale>[Locale('fa'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? c) => Directionality(
        textDirection: TextDirection.rtl,
        child: c ?? const SizedBox.shrink(),
      ),
      home: Scaffold(backgroundColor: const Color(0xFF123F2C), body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
    await _loadIconFont();
  });
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('گالری ورق‌ها', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final List<PlayingCard> cards = <PlayingCard>[
      const PlayingCard(Suit.spades, 14),
      const PlayingCard(Suit.spades, 13),
      const PlayingCard(Suit.hearts, 12),
      const PlayingCard(Suit.hearts, 11),
      const PlayingCard(Suit.diamonds, 10),
      const PlayingCard(Suit.diamonds, 9),
      const PlayingCard(Suit.clubs, 8),
      const PlayingCard(Suit.clubs, 7),
      const PlayingCard(Suit.spades, 6),
      const PlayingCard(Suit.hearts, 5),
      const PlayingCard(Suit.diamonds, 4),
      const PlayingCard(Suit.clubs, 3),
      const PlayingCard(Suit.spades, 2),
      const PlayingCard(Suit.joker, kRedJokerRank),
    ];

    await tester.pumpWidget(
      _wrap(
        ColoredBox(
          color: const Color(0xFF123F2C),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    for (final PlayingCard c in cards)
                      CardView(card: c, width: 108),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    for (final CardBack b in CardBack.values)
                      CardBackView(width: 108, back: b),
                    const CardView(
                      card: PlayingCard(Suit.hearts, 14),
                      width: 108,
                      selected: true,
                    ),
                    const CardView(
                      card: PlayingCard(Suit.clubs, 14),
                      width: 108,
                      playable: true,
                      isTrump: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('golden/cards.png'),
    );
  });

  testWidgets('میز بازی', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final AppSettings settings = AppSettings()..speed = GameSpeed.slow;
    final GameController controller =
        GameController(settings: settings, random: Random(12))..newGame();

    // وضعیتی واقعی بساز: حراج تمام شود، حکم اعلام شود و دو برگ روی میز باشد.
    final ShelemEngine e = controller.engine!;
    final Random r = Random(7);
    int guard = 0;
    while (guard < 400) {
      if (e.phase == GamePhase.playing &&
          e.trick.length >= 2 &&
          e.completedTricks.length >= 2) {
        break;
      }
      if (e.phase == GamePhase.playing && e.turn == 0) {
        e.playCard(0, ShelemBot.chooseCard(e, 0, Difficulty.hard, rng: r));
      } else {
        botStep(e, Difficulty.hard, r);
      }
      guard++;
    }

    await tester.pumpWidget(_wrap(GameScreen(controller: controller)));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 900));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 900));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('golden/table.png'),
    );

    controller.quitToMenu();
    await tester.pump();
    controller.dispose();
  });

  testWidgets('گالری محیط‌ها', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            crossAxisCount: 4,
            childAspectRatio: 0.72,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: <Widget>[
              for (final TableSurface t in TableSurface.values)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFC8A24A)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (t.asset != null)
                        Image.asset(t.asset!, fit: BoxFit.cover)
                      else
                        const ColoredBox(color: Color(0xFF156B4A)),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: ColoredBox(
                          color: const Color(0xCC000000),
                          child: SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                t.fa,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF6E7C1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final BuildContext context = tester.element(find.byType(MaterialApp));
      for (final TableSurface t in TableSurface.values) {
        if (t.asset != null) {
          await precacheImage(AssetImage(t.asset!), context);
        }
      }
    });
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('golden/surfaces.png'),
    );
  });

  testWidgets('میزِ دو نفره', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final AppSettings settings = AppSettings()..speed = GameSpeed.slow;
    settings.rules = settings.rulesWith(players: 2);
    final GameController controller =
        GameController(settings: settings, random: Random(31))..newGame();

    final ShelemEngine e = controller.engine!;
    final Random r = Random(17);
    int guard = 0;
    while (guard < 400) {
      if (e.phase == GamePhase.playing &&
          e.trick.length == 1 &&
          e.completedTricks.length >= 2) {
        break;
      }
      if (e.phase == GamePhase.playing && e.turn == 0) {
        e.playCard(0, ShelemBot.chooseCard(e, 0, Difficulty.hard, rng: r));
      } else {
        botStep(e, Difficulty.hard, r);
      }
      guard++;
    }

    await tester.pumpWidget(_wrap(GameScreen(controller: controller)));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 900));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 900));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('golden/duel.png'),
    );

    controller.quitToMenu();
    await tester.pump();
    controller.dispose();
  });

  testWidgets('دستِ بازیکن در مرحلهٔ حراج', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final AppSettings settings = AppSettings()..speed = GameSpeed.slow;
    final GameController controller =
        GameController(settings: settings, random: Random(4))..newGame();
    final ShelemEngine e = controller.engine!;
    int guard = 0;
    while (e.phase == GamePhase.bidding && e.bidder != 0 && guard < 20) {
      botStep(e, Difficulty.hard, Random(9));
      guard++;
    }

    await tester.pumpWidget(_wrap(GameScreen(controller: controller)));
    await tester.pump(const Duration(milliseconds: 900));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('golden/bidding.png'),
    );

    controller.quitToMenu();
    await tester.pump();
    controller.dispose();
  });
}
