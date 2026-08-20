import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'audio/sound_manager.dart';
import 'core/error_reporter.dart';
import 'core/app_strings.dart';
import 'core/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'storage/save_manager.dart';
import 'storage/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorReporter.install();

  // بازی حکم عمودی طراحی شده است.
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp]);

  final settings = await SettingsController.load();
  final saveManager = await SaveManager.load();

  runApp(HokmApp(settings: settings, saveManager: saveManager));
}

/// ریشهٔ اپلیکیشن.
class HokmApp extends StatefulWidget {
  const HokmApp({
    super.key,
    required this.settings,
    required this.saveManager,
  });

  final SettingsController settings;
  final SaveManager saveManager;

  @override
  State<HokmApp> createState() => _HokmAppState();
}

class _HokmAppState extends State<HokmApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// رفتن اپلیکیشن به پس‌زمینه → مکث موسیقی؛ بازگشت → ادامه.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        SoundManager.instance.handleAppResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        SoundManager.instance.handleAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home:
          HomeScreen(settings: widget.settings, saveManager: widget.saveManager),
    );
  }
}
