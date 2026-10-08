import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'data/analytics/analytics_service.dart';
import 'data/settings/settings_service.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Composition root: services are created once before the first frame —
  // startup stays fast because this only opens a local SQLite file and
  // reads SharedPreferences.
  final services = await AppServices.create();

  // Post-boot maintenance (fire and forget — never blocks the UI).
  _scheduleStartupTasks(services);

  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const TaalebinApp(),
    ),
  );
}

Future<void> _scheduleStartupTasks(AppServices services) async {
  try {
    final settings = await services.settingsService.load();
    if (settings.notificationsEnabled) {
      // Re-arm the daily reminder (covers the case where the OS cleared
      // alarms after a reboot before our BootReceiver could reschedule).
      await services.notificationScheduler.initialize();
      await services.notificationScheduler.scheduleDaily(
        settings.notificationHour,
        settings.notificationMinute,
      );
    }
    services.analytics.logEvent(AnalyticsEvent.appOpen.id);
  } catch (_) {
    // Maintenance failures must never block or crash startup (spec §36).
  }
}

class TaalebinApp extends ConsumerWidget {
  const TaalebinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final themeMode = switch (settings.themeMode) {
      ThemeModeSetting.dark => ThemeMode.dark,
      ThemeModeSetting.light => ThemeMode.light,
      ThemeModeSetting.system => ThemeMode.system,
    };

    return MaterialApp(
      title: 'طالع بین',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.themeFor(settings.themeSkin),
      themeMode: themeMode,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const AppGate(),
    );
  }
}
