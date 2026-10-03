import 'package:fale_hafez/config.dart';
import 'package:fale_hafez/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// صفحهٔ دربارهٔ ما
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// باز کردن لینک در مرورگر/اپلیکیشن خارجی
  Future<void> _launchLink(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // در صورت عدم امکان باز کردن لینک، خطا نادیده گرفته می‌شود
    }
  }

  Widget _socialButton({required String assetPath, required String url}) {
    return IconButton(
      onPressed: () => _launchLink(url),
      icon: SvgPicture.asset(
        assetPath,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }

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
                    Image.asset(
                      'assets/applogo.png',
                      width: width / 2,
                    ),
                    SizedBox(height: height / 30),
                    SizedBox(
                      width: width / 1.2,
                      child: Text(
                        ''' خواجه شمسُ‌الدّینْ محمّدِ بن بهاءُالدّینْ محمّدْ حافظِ شیرازی مشهور به لِسانُ‌الْغِیْب، تَرجُمانُ الْاَسرار، لِسانُ‌الْعُرَفا و ناظِمُ‌الاُولیاء،متخلص به حافظ، شاعر فارسی‌گوی ایرانی بود. بیش‌تر شعرهای او غزل است. مشهور است که حافظ به شیوهٔ سخن‌پردازی خواجوی کرمانی گرویده و همانندیِ سخنش با شعرِ خواجو مشهور است.''',
                        textAlign: TextAlign.center,
                        locale: const Locale('fa'),
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.vazirmatn(
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
                        style: GoogleFonts.vazirmatn(
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: height / 200),
                    Text(
                      ':طراح و توسعه دهنده',
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.vazirmatn(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: height / 80),
                    Text(
                      'امیررضا جلوس حقی',
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.vazirmatn(
                        color: Colors.white,
                        fontSize: 30,
                      ),
                    ),
                    SizedBox(height: height / 50),
                    SizedBox(
                      width: width / 1.5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _socialButton(
                            assetPath: Assets.instagram,
                            url: 'https://instagram.com/amirrezahaqi',
                          ),
                          _socialButton(
                            assetPath: Assets.linkedin,
                            url: 'https://www.linkedin.com/in/amirreza-haqi/',
                          ),
                          _socialButton(
                            assetPath: Assets.twitter,
                            url: 'https://twitter.com/amirrezahaqi',
                          ),
                          _socialButton(
                            assetPath: Assets.github,
                            url: 'https://github.com/amirrezahaqi',
                          ),
                        ],
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
                    style: GoogleFonts.vazirmatn(color: Colors.white),
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
