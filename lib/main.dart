import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/migration/app_migration.dart';
import 'core/theme/app_theme.dart';
import 'database/app_database.dart';
import 'core/utils/app_messenger.dart';
import 'providers/app_providers.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // به‌روزرسانی ساختار داده‌ها **پیش از** ساخت رابط کاربری اجرا می‌شود.
  //
  // چرا این‌جا؟ چون اپلیکیشن روبی از قبل روی گوشی کاربران نصب است؛ اندروید
  // هنگام نصب نسخه‌ی تازه، داده‌ی نسخه‌ی قبلی را نگه می‌دارد و باید یک بار
  // (و به‌صورت قابل‌ازسرگیری) به ساختار تازه تبدیل شود. اجرای این کار پیش از
  // runApp تضمین می‌کند هیچ صفحه‌ای داده‌ی نیمه‌مهاجرت‌شده نبیند.
  // این تابع هرگز استثنا پرتاب نمی‌کند: در بدترین حالت، برنامه با داده‌ی
  // فعلی بالا می‌آید و مهاجرت در اجرای بعدی ادامه پیدا می‌کند.
  // یک نمونه‌ی پایگاه‌داده برای کل برنامه؛ مهاجرت هم از همین نمونه استفاده
  // می‌کند تا فایل SQLite نسخه‌ی قبلی دو بار باز نشود.
  final database = AppDatabase();
  final migrationReport = await AppMigration.instance.runOnStartup(database: database);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        migrationReportProvider.overrideWithValue(migrationReport),
      ],
      child: const FactorRubyApp(),
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
      scaffoldMessengerKey: AppMessenger.key,
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
