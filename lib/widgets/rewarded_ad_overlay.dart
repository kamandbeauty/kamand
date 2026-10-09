import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// تبلیغِ جایزه‌ایِ تمام‌صفحه (نمونهٔ داخلی، بدونِ SDKِ خارجی): کاربر
/// باید شمارشِ معکوس را تا انتها تماشا کند تا جایزه — باز شدنِ
/// قابلیتِ پرمیومِ ساده — فعال شود. خروجِ قبل از پایان = بدونِ جایزه.
Future<bool> showRewardedAdOverlay(BuildContext context) async {
  final earned = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => const _RewardedAdPage(),
    ),
  );
  return earned ?? false;
}

class _RewardedAdPage extends StatefulWidget {
  const _RewardedAdPage();

  @override
  State<_RewardedAdPage> createState() => _RewardedAdPageState();
}

class _RewardedAdPageState extends State<_RewardedAdPage> {
  static const _seconds = 5;
  int _left = _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _left == 0;
    return Scaffold(
      backgroundColor: AstralTokens.deepSpace,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // خلاقیتِ تبلیغ — گیفِ تمام‌صفحه
          Image.asset(
            'assets/ads/sample_rewarded.gif',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          // اسکریمِ پایین برای خواناییِ دکمه‌ها
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.55, 1],
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'تبلیغ',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('بستن'),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        done
                            ? 'تبلیغ تمام شد — جایزهٔ شما آماده است'
                            : 'جایزهٔ شما پس از $_left ثانیه فعال می‌شود',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (done)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AstralTokens.celestialGold,
                              foregroundColor: const Color(0xFF14122B),
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            icon: const Icon(Icons.redeem_outlined, size: 18),
                            label: const Text('دریافت جایزه'),
                          ),
                        )
                      else
                        const Text(
                          'نمونهٔ نمایشی — در نسخهٔ نهایی، تبلیغِ واقعی این‌جا پخش می‌شود',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white54,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
