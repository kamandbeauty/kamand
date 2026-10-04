import 'dart:math' as math;

import 'package:fale_hafez/falscreen.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/widgets/app_brand.dart';
import 'package:fale_hafez/widgets/glass_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// صفحهٔ نیّت و گرفتن فال - به سبک آیین سنتی استخاره با دیوان حافظ:
/// ابتدا متن آیین نیّت خوانده می‌شود و سپس کاربر با «نگه‌داشتن انگشت»
/// روی اثر انگشت، فال خود را می‌گیرد.
class NiyyatScreen extends StatefulWidget {
  const NiyyatScreen({super.key});

  @override
  State<NiyyatScreen> createState() => _NiyyatScreenState();
}

class _NiyyatScreenState extends State<NiyyatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Color _accent = Color.fromRGBO(234, 158, 77, 1);
  static const Color _dark = Color.fromRGBO(107, 38, 15, 1);
  static const Color _bracket = Color(0xFF2E8B57);

  /// مدت نگه‌داشتن انگشت تا گرفتن فال
  static const Duration _holdDuration = Duration(milliseconds: 800);

  /// بیت‌های آیین نیّت برای گرفتن فال از حافظ (روایت سنتی کهن)
  static const List<String> _niyyatVerses = [
    'حافظ ای حافظ شیرازی، بر من نظر اندازی',
    'من طالب یک رازم، تو کاشف هر فالی',
    'به شاخِ نبات، قمری دم به قولی که در سینه داری',
    'این فال مرا بکشای',
  ];

  late final AnimationController _hold =
      AnimationController(vsync: this, duration: _holdDuration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _openFal();
          }
        });

  /// جلوگیری از باز کردن چند صفحهٔ فال پشت سر هم
  bool _wentToFal = false;

  /// فقط برای تست: پیشرفت انیمیشن نگه‌داشتن اثر انگشت
  @visibleForTesting
  double get holdProgress => _hold.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// اگر کاربر هنگام نگه‌داشتن انگشت اپ را مینیمایز کند، انیمیشنِ
  /// نیمه‌کاره در زندگی می‌ماند و با بازگشت — بدون انگشت روی صفحه —
  /// ممکن بود به شکل شبح‌وار ادامه یابد؛ پس با خروج از پیش‌زمینه،
  /// اول ریست می‌شود و کاربر پس از بازگشت از نو نگه می‌دارد.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_hold.status != AnimationStatus.completed) {
        _hold.reset();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hold.dispose();
    super.dispose();
  }

  void _openFal() {
    if (_wentToFal) return;
    _wentToFal = true;
    HapticFeedback.mediumImpact();
    final future = Get.to(() => const FalScreen());
    future?.then((_) {
      if (!mounted) return;
      setState(() => _wentToFal = false);
      _hold.reset();
    });
  }

  void _startHold(TapDownDetails _) {
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  void _cancelHold([TapUpDetails? _]) {
    if (_hold.status != AnimationStatus.completed &&
        _hold.status != AnimationStatus.dismissed) {
      _hold.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // اندازهٔ اسکنر متناسب با ارتفاع صفحه تا روی صفحه‌های کوتاه
              // (یا لندسکیپ) سرریز رخ ندهد
              final double scanner =
                  (constraints.maxHeight * 0.26).clamp(110.0, 210.0);
              // ارتفاع نوار بالایی محدود و وابسته به عرض می‌ماند تا
              // لوگو (ابعاد دلخواه تصویر) باعث سرریز نشود
              final double headerH = (width / 10).clamp(36.0, 60.0);

              // روی صفحه‌های کوتاه یا لندسکیپ: محتوا به‌جای Overflow
              // اسکرول می‌شود؛ روی صفحه‌های معمولی با ConstrainedBox+Spacer
              // همان چیدمان قبلی (top/…/bottom) حفظ می‌شود.
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                  // نوار بالایی: دکمهٔ بازگشت و لوگو (سبک صفحهٔ فال)
                  Padding(
                    padding: EdgeInsets.only(
                      top: topPadding + 12,
                      right: 10,
                      left: 10,
                    ),
                    child: GlassPanel(
                      radius: 16,
                      blur: 12,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _headerButton(
                            size: headerH,
                            icon: CupertinoIcons.back,
                            onPressed: Get.back,
                          ),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AppBrand(fontSize: 17, onDark: true),
                          ),
                          SizedBox(width: headerH),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // متن آیین نیّت
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _dark.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          for (final verse in _niyyatVerses)
                            Text(
                              verse,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                              style: vazirText(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: _dark,
                                height: 1.9,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // قاب اسکنر و اثر انگشت - نگه‌داشتن انگشت برای گرفتن فال
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: _startHold,
                    onTapUp: _cancelHold,
                    onTapCancel: () => _cancelHold(),
                    child: SizedBox(
                      width: scanner,
                      height: scanner,
                      child: CustomPaint(
                        painter: _CornerBracketsPainter(color: _bracket),
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _hold,
                            builder: (context, child) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // حلقهٔ پیشرفت دایره‌ای با گرادیان طلایی،
                                  // هالهٔ نور و سرِ دنباله‌دارِ درخشان
                                  SizedBox(
                                    width: scanner * 0.84,
                                    height: scanner * 0.84,
                                    child: CustomPaint(
                                      painter: _ProgressRingPainter(
                                          progress: _hold.value),
                                    ),
                                  ),
                                  // اثر انگشتِ دست‌ساز: خطوط قوسی که با
                                  // پیشرفت اسکن، کم‌کم قرمزِ درخشان می‌شوند
                                  Transform.scale(
                                    scale: 1.0 + _hold.value * 0.08,
                                    child: SizedBox(
                                      width: scanner * 0.62,
                                      height: scanner * 0.62,
                                      child: CustomPaint(
                                        key: const Key('fingerprint_print'),
                                        painter: _FingerprintPainter(
                                            progress: _hold.value),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // راهنمای کاربر
                  Text(
                    'نیّت کنید و اشاره‌ای بفرمایید',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: vazirText(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'انگشت خود را روی اثر انگشت نگه دارید',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: vazirText(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),

                  const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _headerButton({
    required double size,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.yellow,
          backgroundColor: _accent,
          shadowColor: const Color.fromRGBO(183, 116, 50, 1),
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, color: _dark),
      ),
    );
  }
}

/// نقاش چهار گوشهٔ قاب اسکنر اثر انگشت (مانند کادر دوربین)
class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double arm = 42;
    const double inset = 4;

    // گوشهٔ بالا-راست
    canvas
      ..drawLine(Offset(size.width - inset - arm, inset),
          Offset(size.width - inset, inset), paint)
      ..drawLine(Offset(size.width - inset, inset),
          Offset(size.width - inset, inset + arm), paint)
      // گوشهٔ بالا-چپ
      ..drawLine(
          const Offset(inset + arm, inset), const Offset(inset, inset), paint)
      ..drawLine(
          const Offset(inset, inset), const Offset(inset, inset + arm), paint)
      // گوشهٔ پایین-راست
      ..drawLine(Offset(size.width - inset - arm, size.height - inset),
          Offset(size.width - inset, size.height - inset), paint)
      ..drawLine(Offset(size.width - inset, size.height - inset - arm),
          Offset(size.width - inset, size.height - inset), paint)
      // گوشهٔ پایین-چپ
      ..drawLine(Offset(inset + arm, size.height - inset),
          Offset(inset, size.height - inset), paint)
      ..drawLine(Offset(inset, size.height - inset - arm),
          Offset(inset, size.height - inset), paint);
  }

  @override
  bool shouldRepaint(_CornerBracketsPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// حلقهٔ پیشرفت دایره‌ایِ نگه‌داشتن انگشت:
/// ریلِ نازک + قوسِ گرادیانیِ طلایی با درخششِ نرم و نقطهٔ نورانی در نوک قوس.
class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({required this.progress});

  static const _gold = Color(0xFFEA9E4D);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * 0.07;
    final radius = size.width / 2 - stroke * 1.6;

    // ریلِ پس‌زمینهٔ ظریف
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.65
      ..color = Colors.white.withOpacity(0.26);
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.002) return;

    const start = -math.pi / 2;
    final sweep = math.pi * 2 * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // هالهٔ نرم زیر قوس
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 2.3
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.3)
      ..color = _gold.withOpacity(0.5 * progress);
    canvas.drawArc(rect, start, sweep, false, glowPaint);

    // قوسِ اصلی با گرادیانِ طلایی (از کهرباییِ تیره به کرمِ روشن در نوک)
    final gradient = SweepGradient(
      startAngle: start,
      endAngle: start + sweep,
      colors: const [
        Color(0xFFB96A20),
        Color(0xFFEA9E4D),
        Color(0xFFFFDFA6),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);
    canvas.drawArc(rect, start, sweep, false, arcPaint);

    // سرِ دنباله‌دار: نقطهٔ نورانیِ در حال حرکت روی نوک قوس
    if (progress > 0.01) {
      final tipAngle = start + sweep;
      final tip = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );
      const cream = Color(0xFFFFF3D6);
      canvas.drawCircle(
        tip,
        stroke * 1.05,
        Paint()
          ..color = cream.withOpacity(0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.85),
      );
      canvas.drawCircle(tip, stroke * 0.42, Paint()..color = cream);
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}

/// اثر انگشتِ دست‌ساز: قوس‌های تو‌در‌توی ارگانیک (به سبک Touch ID)
/// که با پیشرفتِ اسکن، کم‌کم از مرکز به سوی بیرون قرمزِ درخشان می‌شوند.
class _FingerprintPainter extends CustomPainter {
  const _FingerprintPainter({required this.progress});

  static const _baseRed = Color(0xFF8E2820);
  static const _litRed = Color(0xFFE0452F);
  static const _gold = Color(0xFFEA9E4D);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * 0.045;
    const ridges = 6;

    // هالهٔ گرمی که با شروعِ اسکن پشتِ اثر انگشت پدیدار می‌شود
    if (progress > 0.01) {
      canvas.drawCircle(
        center,
        size.width * 0.42,
        Paint()
          ..color = _gold.withOpacity(0.10 + 0.22 * progress)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.14),
      );
    }

    final ridgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < ridges; i++) {
      final r = size.width * (0.46 - i * 0.072);
      if (r <= stroke * 2) break;
      final rect = Rect.fromCircle(center: center, radius: r);
      // شروع و زاویهٔ متفاوتِ هر قوس برای حسِ ارگانیکِ خط‌های اثر انگشت
      final startA = -math.pi * 0.72 - i * 0.42;
      final sweepA = math.pi * (1.16 + i * 0.10);
      // ظاهر شدنِ تدریجیِ هر خط متناسب با پیشرفت اسکن (تاخیرِ پلکانی)
      final reveal = (progress * (ridges + 1) - i).clamp(0.0, 1.0);
      ridgePaint.color =
          Color.lerp(_baseRed.withOpacity(0.30), _litRed, reveal)!;
      canvas.drawArc(rect, startA, sweepA, false, ridgePaint);
    }

    // قلبِ اثر انگشت: نقطهٔ مرکزی + قوس کوچکِ دور آن
    final coreReveal = (progress * (ridges + 1) - ridges).clamp(0.0, 1.0);
    final core = size.width * 0.035;
    canvas.drawCircle(
      center,
      core,
      Paint()
        ..color = Color.lerp(
            _baseRed.withOpacity(0.30), _litRed, coreReveal)!,
    );
  }

  @override
  bool shouldRepaint(_FingerprintPainter old) => old.progress != progress;
}
