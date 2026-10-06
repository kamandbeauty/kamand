/// شلم — بازی ورق ایرانی (یک بازیکن + سه ربات).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/game_controller.dart';
import 'state/settings.dart';
import 'ui/screens/menu_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF13100C),
  ));
  final AppSettings settings = await AppSettings.load();
  runApp(ShelemApp(settings: settings));
}

class ShelemApp extends StatefulWidget {
  const ShelemApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<ShelemApp> createState() => _ShelemAppState();
}

class _ShelemAppState extends State<ShelemApp> {
  late final GameController controller =
      GameController(settings: widget.settings);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شلم',
      debugShowCheckedModeBanner: false,
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
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: MenuScreen(controller: controller),
    );
  }
}
