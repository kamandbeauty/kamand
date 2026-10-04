import 'package:fale_hafez/config.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:flutter/material.dart';

/// صفحهٔ دربارهٔ ما
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double height = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/background/about-bg.png'),
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
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(width / 10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(width / 10),
                        child: Image.asset(
                          'assets/appicon.png',
                          width: width / 2,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: height / 30),
                    SizedBox(
                      width: width / 1.2,
                      child: Text(
                        ''' خواجه شمسُ‌الدّینْ محمّدِ بن بهاءُالدّینْ محمّدْ حافظِ شیرازی مشهور به لِسانُ‌الْغِیْب، تَرجُمانُ الْاَسرار، لِسانُ‌الْعُرَفا و ناظِمُ‌الاُولیاء،متخلص به حافظ، شاعر فارسی‌گوی ایرانی بود. بیش‌تر شعرهای او غزل است. مشهور است که حافظ به شیوهٔ سخن‌پردازی خواجوی کرمانی گرویده و همانندیِ سخنش با شعرِ خواجو مشهور است.''',
                        textAlign: TextAlign.center,
                        locale: const Locale('fa'),
                        textDirection: TextDirection.rtl,
                        style: vazirText(
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: height / 150),
                    SizedBox(
                      width: width / 1.2,
                      child: Text(
                        '''فالِ حافظ به‌معنی استفاده از دیوانِ حافظ برای برای پیش‌گوییِ سرنوشت و رفعِ تردید و خوب یا بد بودنِ عاقبتِ کاری یا استعلام از احوالِ شخصِ غایبی است. یکی از باورهای کهن و عمومیِ ایرانیان، فالِ نیک یا بد زدن با دست‌آویزی به رویدادها و اشیاء گوناگون بوده‌است.
        ''',
                        textAlign: TextAlign.center,
                        locale: const Locale('fa'),
                        textDirection: TextDirection.rtl,
                        style: vazirText(
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: height / 200),
                    Text(
                      ':طراح و توسعه دهنده',
                      textAlign: TextAlign.justify,
                      style: vazirText(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: height / 80),
                    Text(
                      'استودیو جاوید',
                      textAlign: TextAlign.center,
                      locale: const Locale('fa'),
                      textDirection: TextDirection.rtl,
                      style: vazirText(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Studio Javid',
                      textAlign: TextAlign.center,
                      style: vazirText(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
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
                    'نسخه برنامه ${AppInfo.version}',
                    style: vazirText(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
