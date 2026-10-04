import 'dart:async';

import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/error_reporter.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/splash.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // گرفتن خطاهای اجرایی برای گزارش‌دهی (فقط ذخیرهٔ محلی روی دستگاه)
    ErrorReporter.init();

    // بارگذاری تنظیمات ذخیره‌شده (قلم، اندازهٔ قلم، اشعار دلخواه و…)
    final settings = SettingsService();
    await settings.load();
    Get.put<SettingsService>(settings, permanent: true);

    // پیش‌گرم کردن کش دیوان از همان ابتدای اجرا تا اولین ورود به
    // «دیوان» یا «فال» بدون مکث بارگذاری JSON انجام شود (به‌ویژه
    // روی دستگاه‌های ضعیف). سه‌ثانیهٔ اسپلش زمانِ کافی برای این I/O است.
    unawaited(DivanRepository.all());

    runApp(MyApp(settings: settings));
  }, (error, stack) => ErrorReporter.record(error.toString(), stack));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return GetMaterialApp(
          title: 'دیوان و فال حافظ',
          theme: ThemeData(
            fontFamily: poemFontFamily(settings.fontKey),
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          debugShowCheckedModeBanner: false,
          home: const MyHomePage(),
        );
      },
    );
  }
}
