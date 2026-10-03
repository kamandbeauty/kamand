import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/splash.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // بارگذاری تنظیمات ذخیره‌شده (قلم، اندازهٔ قلم، اشعار دلخواه)
  final settings = SettingsService();
  await settings.load();
  Get.put<SettingsService>(settings, permanent: true);

  runApp(MyApp(settings: settings));
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
