import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: FactorRubyApp(),
    ),
  );
}

class FactorRubyApp extends ConsumerWidget {
  const FactorRubyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final accent = Color(settings.accentColor);
    return MaterialApp(
      title: 'فاکتور ساز روبی',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightThemeWith(accent),
      darkTheme: AppTheme.darkThemeWith(accent),
      // تم تاریک حذف شده؛ فقط تم روشن با رنگ انتخابی کاربر استفاده می‌شود.
      themeMode: ThemeMode.light,
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
      // همیشه با اسپلش روبی شروع می‌شود
      home: const SplashScreen(),
    );
  }
}
