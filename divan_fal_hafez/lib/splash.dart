import 'package:fale_hafez/config.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/homepage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    Future.delayed(const Duration(seconds: 3)).then((value) {
      // اگر کاربر قبل از پایان اسپلش از صفحه خارج شده باشد، ناوبری انجام نمی‌شود
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()));
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: _SplashView(),
      ),
    );
  }
}

/// نمایش صفحهٔ اسپلش
///
/// تصویر تمام‌صفحهٔ اختصاصی «دیوان و فال حافظ» (اثر استودیو جاوید)،
/// بدون پوشش مجدد لوگو/عنوان؛ فقط اسپینر بارگذاری و شمارهٔ نسخه در
/// پایینِ خوانا (با پردهٔ تیرهٔ ملایم) نمایش داده می‌شوند.
class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // پس‌زمینهٔ تمام‌صفحهٔ اسپلش
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/background/splash.jpg"),
              fit: BoxFit.cover,
            ),
          ),
        ),

        // پردهٔ تیرهٔ ملایم در قسمت پایین برای خوانایی لود و نسخه
        Positioned(
          bottom: 0,
          right: 0,
          left: 0,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.55),
                ],
              ),
            ),
          ),
        ),

        // اسپینر بارگذاری
        const Positioned(
          bottom: 44,
          right: 0,
          left: 0,
          child: Center(
            child: SpinKitFadingFour(
              color: Colors.white,
              size: 34.0,
            ),
          ),
        ),

        // نسخهٔ برنامه
        Positioned(
          bottom: 12,
          right: 5,
          left: 5,
          child: Center(
            child: Text(
              "نسخه برنامه ${AppInfo.version}",
              style: vazirText(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
