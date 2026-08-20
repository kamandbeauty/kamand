import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_strings.dart';
import 'core/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'storage/save_manager.dart';
import 'storage/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // بازی حکم عمودی طراحی شده است.
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp]);

  final settings = await SettingsController.load();
  final saveManager = await SaveManager.load();

  runApp(HokmApp(settings: settings, saveManager: saveManager));
}

/// ریشهٔ اپلیکیشن.
class HokmApp extends StatelessWidget {
  const HokmApp({
    super.key,
    required this.settings,
    required this.saveManager,
  });

  final SettingsController settings;
  final SaveManager saveManager;

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
      home: HomeScreen(settings: settings, saveManager: saveManager),
    );
  }
}
