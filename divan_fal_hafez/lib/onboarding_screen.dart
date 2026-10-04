import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/splash.dart';
import 'package:fale_hafez/widgets/app_brand.dart';
import 'package:fale_hafez/widgets/glass_panel.dart';
import 'package:fale_hafez/widgets/themed_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// معارفهٔ اولین اجرا (سه صفحهٔ شیشه‌ای) — فقط یک‌بار نمایش داده می‌شود.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = <({IconData icon, String title, String body})>[
    (
      icon: CupertinoIcons.book,
      title: 'دیوانِ کامل حافظ',
      body:
          '۴۹۵ غزل به‌همراه رباعیات، قطعات، قصاید و مثنویات، همیشه و کاملاً آفلاین همراه شماست؛ با جستجو و قلم دلخواه.',
    ),
    (
      icon: CupertinoIcons.hand_raised,
      title: 'فال به آیین سنتی',
      body:
          'نیّت کنید، انگشت را روی اثر انگشت نگه دارید تا قطرهٔ جوهر پهن شود و فالتان از میان دیوان برآید.',
    ),
    (
      icon: CupertinoIcons.heart,
      title: 'دلخواه‌ها و تعبیر فال',
      body:
          'تعبیر هر فال را بخوانید، اشعار دلخواه را نشانه‌گذاری کنید و کارت تصویری اشعار را با عزیزانتان به اشتراک بگذارید.',
    ),
  ];

  bool get _isLast => _page == _slides.length - 1;

  Future<void> _finish() async {
    await Get.find<SettingsService>().markOnboardingSeen();
    Get.offAll(() => const MyHomePage());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.viewPaddingOf(context).top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background/homebg.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // نوار بالایی: برند + رد کردن
                Padding(
                  padding: EdgeInsets.only(
                      top: topPadding > 0 ? 6 : 12, right: 16, left: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppBrand(fontSize: 18, onDark: true),
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          'رد کردن',
                          style: vazirText(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                // صفحه‌های معارفه
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final slide = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GlassPanel(
                              radius: 40,
                              blur: 14,
                              padding: const EdgeInsets.all(28),
                              child: Icon(slide.icon,
                                  size: 76, color: const Color(0xFFF0B45C)),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: vazirText(
                                fontFamily: 'Sahel',
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ).copyWith(shadows: const [
                                Shadow(
                                    color: Colors.black87,
                                    blurRadius: 10,
                                    offset: Offset(0, 2)),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            GlassPanel(
                              radius: 18,
                              blur: 12,
                              tintOpacity: 0.72,
                              borderOpacity: 0.30,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              child: Text(
                                slide.body,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: vazirText(
                                  fontSize: 15.5,
                                  color: const Color(0xFF3F2710),
                                  height: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // نقطه‌های پیشرفت + دکمهٔ ادامه
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? const Color(0xFFF0B45C)
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Padding(
                  padding:
                      const EdgeInsets.only(right: 28, left: 28, bottom: 24),
                  child: ElevatedButton(
                    onPressed: _isLast
                        ? _finish
                        : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            ),
                    style: AppThemeButton.style(radius: 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        _isLast ? 'شروع سفر' : 'ادامه',
                        textAlign: TextAlign.center,
                        style: vazirText(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppThemeButton.gold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
