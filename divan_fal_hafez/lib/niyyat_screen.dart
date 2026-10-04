import 'dart:math' as math;

import 'package:fale_hafez/falscreen.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/widgets/glass_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// صفحهٔ نیّت و گرفتن فال روی آثار اختصاصیِ صاحب‌اثر:
/// خودِ تصویر (قابِ طلایی، خوش‌نویسیِ نیّت، دیوانِ باز و حافظیه)
/// تمام روایتِ صفحه است؛ هیچ نوشته‌ای روی آن نیامده و فقط اسکنرِ
/// اثر انگشت، متناسب با ترکیب‌بندی تصویر، روی مُهرِ طلاییِ وسطِ
/// قاب (میان خوش‌نویسی و دیوانِ باز) نشسته است.
class NiyyatScreen extends StatefulWidget {
  const NiyyatScreen({super.key});

  @override
  State<NiyyatScreen> createState() => _NiyyatScreenState();
}

class _NiyyatScreenState extends State<NiyyatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// قابِ گوشه‌های اسکنر: کهرباییِ تیره هم‌رنگِ قابِ طلاییِ تصویر
  static const Color _bracketGold = Color(0xFF8A5A2B);

  /// مدت نگه‌داشتن انگشت تا گرفتن فال
  static const Duration _holdDuration = Duration(milliseconds: 800);

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
    final double topPadding = MediaQuery.viewPaddingOf(context).top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background/faalbg.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // اندازهٔ اسکنر متناسب با ارتفاع صفحه تا روی صفحه‌های کوتاه
              // (یا لندسکیپ) از تصویر بیرون نزند
              final double scanner =
                  (constraints.maxHeight * 0.165).clamp(96.0, 170.0);
              // جایگاه متناسب با ترکیب‌بندی اثر: بلافاصله زیر خوش‌نویسیِ
              // نیّت و روی مُهرِ طلاییِ وسطِ قاب، بالای دیوانِ باز
              final double centerY = constraints.maxHeight * 0.63;

              return Stack(
                children: [
                  // قاب اسکنر و اثر انگشت - نگه‌داشتن انگشت برای گرفتن فال
                  Positioned(
                    top: centerY - scanner / 2,
                    right: (constraints.maxWidth - scanner) / 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: _startHold,
                      onTapUp: _cancelHold,
                      onTapCancel: () => _cancelHold(),
                      child: SizedBox(
                        width: scanner,
                        height: scanner,
                        child: CustomPaint(
                          painter:
                              const _CornerBracketsPainter(_bracketGold),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _hold,
                              builder: (context, child) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // حلقهٔ پیشرفت دایره‌ای با گرادیان
                                    // طلایی و سرِ دنباله‌دارِ درخشان
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
                  ),

                  // راهنمای نگه‌داشتن انگشت زیر اثر انگشت، داخل قاب
                  // شیشه‌ایِ شیری تا روی هر نقطه از تصویر خوانا بماند
                  Positioned(
                    top: centerY + scanner / 2 + 14,
                    right: 0,
                    left: 0,
                    child: Center(
                      child: GlassPanel(
                        radius: 14,
                        blur: 12,
                        tintOpacity: 0.85,
                        borderOpacity: 0.35,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 9),
                        child: Text(
                          'انگشت خود را روی اثر انگشت نگه دارید',
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: vazirText(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF4A2E12),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // دکمهٔ بازگشتِ شیشه‌ایِ شناور (بدون هیچ نوشتهٔ اضافی)
                  Positioned(
                    top: topPadding + 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: Get.back,
                      child: GlassPanel(
                        radius: 14,
                        blur: 12,
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                          CupertinoIcons.back,
                          size: 22,
                          color: Color(0xFF5B3A1E),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// نقاش چهار گوشهٔ قاب اسکنر اثر انگشت (مانند کادر دوربین)
class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.035
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double arm = size.width * 0.24;
    const double inset = 4;

    // گوشهٔ بالا-راست
    canvas
      ..drawLine(Offset(size.width - inset - arm, inset),
          Offset(size.width - inset, inset), paint)
      ..drawLine(Offset(size.width - inset, inset),
          Offset(size.width - inset, inset + arm), paint)
      // گوشهٔ بالا-چپ
      ..drawLine(
          Offset(inset + arm, inset), const Offset(inset, inset), paint)
      ..drawLine(
          const Offset(inset, inset), Offset(inset, inset + arm), paint)
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

    // ریلِ پس‌زمینهٔ ظریف (کهرباییِ ملایم برای زمینهٔ روشنِ اثر)
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.5
      ..color = const Color(0xFF8A5A2B).withOpacity(0.30);
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
      canvas.drawCircle(
        tip,
        stroke * 1.05,
        Paint()
          ..color = _gold.withOpacity(0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.85),
      );
      // حاشیهٔ کهربایی تا نوکِ روشن روی زمینهٔ کرمِ تصویر هم دیده شود
      canvas.drawCircle(
          tip, stroke * 0.55, Paint()..color = const Color(0xFFB96A20));
      canvas.drawCircle(
          tip, stroke * 0.36, Paint()..color = const Color(0xFFFFF3D6));
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

    // قلبِ اثر انگشت: نقطهٔ مرکزی
    final coreReveal = (progress * (ridges + 1) - ridges).clamp(0.0, 1.0);
    final core = size.width * 0.035;
    canvas.drawCircle(
      center,
      core,
      Paint()
        ..color =
            Color.lerp(_baseRed.withOpacity(0.30), _litRed, coreReveal)!,
    );
  }

  @override
  bool shouldRepaint(_FingerprintPainter old) => old.progress != progress;
}
