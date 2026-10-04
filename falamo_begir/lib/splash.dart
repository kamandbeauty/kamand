import 'package:fale_hafez/config.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/homepage.dart';
import 'package:fale_hafez/widgets/app_brand.dart';
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
    double width = MediaQuery.sizeOf(context).width;
    double height = MediaQuery.sizeOf(context).height;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Stack(children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/background/splash.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              left: 5,
              right: 5,
              top: 20,
              bottom: 20,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // نماد برنامه (آیکون رسمی) به‌جای لوگوی قدیمی
                  Container(
                    width: width / 2.2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(width / 8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(width / 8),
                      child: Image.asset(
                        "assets/appicon.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const AppBrand(fontSize: 28, onDark: true),
                  SizedBox(
                    height: height / 30,
                  ),
                  const SpinKitFadingFour(
                    color: Colors.white,
                    size: 50.0,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 10,
              right: 5,
              left: 5,
              child: Center(
                child: Text(
                  "نسخه برنامه ${AppInfo.version}",
                  style: vazirText(color: Colors.white),
                ),
              ),
            )
          ]),
        ),
      ),
    );
  }
}
