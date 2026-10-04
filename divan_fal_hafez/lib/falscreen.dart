import 'package:fale_hafez/about.dart';
import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/poem.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/widgets/app_brand.dart';
import 'package:fale_hafez/widgets/glass_button.dart';
import 'package:fale_hafez/widgets/glass_panel.dart';
import 'package:fale_hafez/widgets/themed_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

/// صفحهٔ نمایش فال حافظ.
///
/// فال‌ها از دیتاست آفلاین داخل برنامه (کل دیوان حافظ - ۴۹۵ غزل)
/// خوانده می‌شوند؛ بدون نیاز به اینترنت.
class FalScreen extends StatefulWidget {
  const FalScreen({super.key});

  @override
  State<FalScreen> createState() => _FalScreenState();
}

class _FalScreenState extends State<FalScreen> {
  Poem? _fal;

  bool _isLoading = true;
  bool _hasError = false;

  /// انتخاب تصادفی یک فال از میان ۴۹۵ فال ذخیره‌شده در برنامه
  Future<void> _pickFal() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final fal = await DivanRepository.randomGhazal();
      if (!mounted) return;
      setState(() {
        _fal = fal;
        _isLoading = false;
      });
    } catch (_) {
      _showError();
    }
  }

  void _showError() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _pickFal();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double height = MediaQuery.sizeOf(context).height;
    final double topPadding = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background/poems.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // محتوای اصلی: لودینگ / خطا / نمایش فال
            _buildBody(width, height),

            // نوار بالایی: دکمهٔ بازگشت، لوگو و دربارهٔ ما
            Positioned(
              top: topPadding + 12,
              right: 10,
              left: 10,
              child: GlassPanel(
                tintOpacity: 0.30,
                borderOpacity: 0.55,
                radius: 16,
                blur: 12,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _headerButton(
                      width: width,
                      icon: CupertinoIcons.back,
                      onPressed: Get.back,
                    ),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AppBrand(fontSize: 18, onDark: false),
                    ),
                    _headerButton(
                      width: width,
                      icon: CupertinoIcons.person_alt_circle,
                      onPressed: () => Get.to(const AboutScreen()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerButton({
    required double width,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return AppThemeButton.icon(
      icon: icon,
      onPressed: onPressed,
      size: width / 10,
    );
  }

  Widget _buildBody(double width, double height) {
    // وضعیت در حال بارگذاری
    if (_isLoading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SpinKitFadingFour(
            color: Color.fromRGBO(107, 38, 15, 1),
            size: 50,
          ),
          const SizedBox(height: 20),
          Text(
            'در حال گرفتن فال...',
            textAlign: TextAlign.center,
            locale: const Locale('fa'),
            textDirection: TextDirection.rtl,
            style: vazirText(
              fontSize: 18,
              color: const Color.fromRGBO(107, 38, 15, 1),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    // وضعیت خطا (مشکل در خواندن دیتای داخل برنامه) + دکمهٔ تلاش مجدد
    if (_hasError || _fal == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color.fromRGBO(107, 38, 15, 1),
            size: 60,
          ),
          const SizedBox(height: 20),
          Text(
            'خطا در بارگذاری فال‌ها ؛ لطفا دوباره تلاش کنید',
            textAlign: TextAlign.center,
            locale: const Locale('fa'),
            textDirection: TextDirection.rtl,
            style: vazirText(
              fontSize: 18,
              color: const Color.fromRGBO(107, 38, 15, 1),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          GlassButton(
            onPressed: _pickFal,
            icon: Icons.refresh,
            label: 'تلاش مجدد',
            expand: false,
            tint: const Color.fromRGBO(234, 158, 77, 1),
            tintOpacity: 0.32,
            borderOpacity: 0.5,
            textColor: const Color.fromRGBO(107, 38, 15, 1),
            iconColor: const Color.fromRGBO(107, 38, 15, 1),
            fontSize: 16,
            height: 50,
            radius: 12,
          ),
        ],
      );
    }

    // نمایش فال انتخاب‌شده
    final fal = _fal!;
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: height / 7),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width / 14),
            child: GlassPanel(
              tintOpacity: 0.42,
              borderOpacity: 0.60,
              radius: 20,
              blur: 16,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Text(
                    'شماره صفحه فال شما : ${fal.number}',
                    textAlign: TextAlign.center,
                    locale: const Locale('fa'),
                    textDirection: TextDirection.rtl,
                    style: vazirText(
                      fontSize: 18,
                      color: const Color.fromRGBO(107, 38, 15, 1),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 1.4,
                    width: 120,
                    color: const Color.fromRGBO(107, 38, 15, 0.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fal.verses,
                    textAlign: TextAlign.center,
                    locale: const Locale('fa'),
                    textDirection: TextDirection.rtl,
                    style: vazirText(
                      fontSize: 18,
                      color: const Color.fromRGBO(107, 38, 15, 1),
                      fontWeight: FontWeight.w900,
                      height: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: height / 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width / 14),
            child: GlassPanel(
              tintOpacity: 0.42,
              borderOpacity: 0.60,
              radius: 20,
              blur: 16,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 22),
              child: Column(
                children: [
                  Text(
                    'تفسیر فال شما',
                    textAlign: TextAlign.center,
                    locale: const Locale('fa'),
                    textDirection: TextDirection.rtl,
                    style: vazirText(
                      fontSize: 18,
                      color: const Color.fromRGBO(107, 38, 15, 1),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 1.4,
                    width: 100,
                    color: const Color.fromRGBO(107, 38, 15, 0.35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fal.meaning ?? '',
                    textAlign: TextAlign.center,
                    locale: const Locale('fa'),
                    textDirection: TextDirection.rtl,
                    style: vazirText(
                      fontSize: 16,
                      color: const Color.fromRGBO(107, 38, 15, 1),
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: height / 20),
        ],
      ),
    );
  }
}
