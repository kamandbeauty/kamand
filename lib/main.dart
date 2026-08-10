import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'providers/app_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: FactorFidaApp(),
    ),
  );
}

class FactorFidaApp extends ConsumerWidget {
  const FactorFidaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final settings = ref.watch(settingsProvider);

    ThemeMode currentThemeMode = ThemeMode.light;
    if (settings.themeMode == 'dark') {
      currentThemeMode = ThemeMode.dark;
    } else if (settings.themeMode == 'system') {
      currentThemeMode = ThemeMode.system;
    }

    return MaterialApp(
      title: 'فاکتور فیدا',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: currentThemeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fa', 'IR'),
      ],
      locale: const Locale('fa', 'IR'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: user.isOnboarded ? const DashboardScreen() : const OnboardingScreen(),
    );
  }
}
