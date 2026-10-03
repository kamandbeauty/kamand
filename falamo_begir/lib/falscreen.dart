import 'dart:convert';
import 'package:fale_hafez/about.dart';
import 'package:fale_hafez/config.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

/// صفحهٔ نمایش فال حافظ
class FalScreen extends StatefulWidget {
  const FalScreen({super.key});

  @override
  State<FalScreen> createState() => _FalScreenState();
}

class _FalScreenState extends State<FalScreen> {
  String _rhyme = '';
  String _meaning = '';
  String _shomare = '';

  bool _isLoading = true;
  bool _hasError = false;

  /// دریافت یک فال تصادفی از سرویس فال حافظ
  Future<void> _fetchFal() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await http
          .get(ApiConfig.hafezEndpoint)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result =
            (data['result'] ?? <String, dynamic>{}) as Map<String, dynamic>;
        setState(() {
          _rhyme = result['RHYME']?.toString() ?? '';
          _meaning = result['MEANING']?.toString() ?? '';
          _shomare = result['SHOMARE']?.toString() ?? '';
          _isLoading = false;
        });
      } else {
        _showError();
      }
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
    _fetchFal();
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
                  image: AssetImage('assets/background/falscreen.png'),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _headerButton(
                    width: width,
                    icon: CupertinoIcons.back,
                    onPressed: Get.back,
                  ),
                  Image.asset(
                    'assets/logotext.png',
                    width: width / 2,
                  ),
                  _headerButton(
                    width: width,
                    icon: CupertinoIcons.person_alt_circle,
                    onPressed: () => Get.to(const AboutScreen()),
                  ),
                ],
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
    return SizedBox(
      width: width / 10,
      height: width / 10,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.yellow,
          backgroundColor: const Color.fromRGBO(234, 158, 77, 1),
          shadowColor: const Color.fromRGBO(183, 116, 50, 1),
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          icon,
          color: const Color.fromRGBO(107, 38, 15, 1),
        ),
      ),
    );
  }

  Widget _buildBody(double width, double height) {
    // وضعیت در حال بارگذاری
    if (_isLoading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SpinKitFadingFour(
            color: Colors.white,
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
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    // وضعیت خطا (قطع اینترنت یا خطای سرور) + دکمهٔ تلاش مجدد
    if (_hasError) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/wifi.png',
            height: height / 6,
          ),
          const SizedBox(height: 20),
          Text(
            'لطفا اتصال اینترنت خود را بررسی نمایید',
            textAlign: TextAlign.center,
            locale: const Locale('fa'),
            textDirection: TextDirection.rtl,
            style: vazirText(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchFal,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.yellow,
              backgroundColor: const Color.fromRGBO(234, 158, 77, 1),
              shadowColor: const Color.fromRGBO(183, 116, 50, 1),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(
              Icons.refresh,
              color: Color.fromRGBO(107, 38, 15, 1),
            ),
            label: Text(
              'تلاش مجدد',
              style: vazirText(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: const Color.fromRGBO(107, 38, 15, 1),
              ),
            ),
          ),
        ],
      );
    }

    // نمایش فال دریافت‌شده
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: height / 7),
          Text(
            'شماره صفحه فال شما : $_shomare',
            textAlign: TextAlign.center,
            locale: const Locale('fa'),
            textDirection: TextDirection.rtl,
            style: vazirText(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: height / 20),
          Text(
            _rhyme,
            textAlign: TextAlign.center,
            locale: const Locale('fa'),
            textDirection: TextDirection.rtl,
            style: vazirText(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: height / 20),
          const Divider(),
          SizedBox(height: height / 20),
          Text(
            'تفسیر فال شما',
            textAlign: TextAlign.center,
            locale: const Locale('fa'),
            textDirection: TextDirection.rtl,
            style: vazirText(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: height / 30),
          SizedBox(
            width: width / 1.2,
            child: Text(
              _meaning,
              textAlign: TextAlign.center,
              locale: const Locale('fa'),
              textDirection: TextDirection.rtl,
              style: vazirText(fontSize: 16, color: Colors.white),
            ),
          ),
          SizedBox(height: height / 20),
        ],
      ),
    );
  }
}
