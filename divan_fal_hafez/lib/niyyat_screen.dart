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
/// روایتِ صفحه است؛ روی آن فقط اسکنرِ اثر انگشت، متناسب با
/// ترکیب‌بندی اثر، میان خوش‌نویسی و دیوانِ باز نشسته است.
/// با لمس، قطره‌ای جوهر زیر انگشت پخش و به‌تدریج بزرگ می‌شود تا
/// دور اثر انگشت را بگیرد و خط‌های اثر انگشت درون آن جا می‌افتند.
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
              // (یا لندسکیپ) از تصویر بیرون نزند؛ اثر انگشت اندکی بزرگ‌تر
              // از اثر انگشتِ واقعی طراحی شده است
              final double scanner =
                  (constraints.maxHeight * 0.17).clamp(110.0, 185.0);
              // جایگاه متناسب با ترکیب‌بندی اثر: میان خوش‌نویسیِ نیّت و
              // دیوانِ باز، در مرکز قاب
              final double centerY = constraints.maxHeight * 0.625;

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
                          painter: const _CornerBracketsPainter(_bracketGold),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _hold,
                              builder: (context, child) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // قطرهٔ جوهر که زیر انگشت پخش و
                                    // به‌تدریج دور اثر انگشت را می‌گیرد
                                    SizedBox(
                                      width: scanner * 0.80,
                                      height: scanner * 0.80,
                                      child: CustomPaint(
                                        painter: _InkBloomPainter(
                                            progress: _hold.value),
                                      ),
                                    ),
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
                                    // اثر انگشتِ واقعی: خطوط تو‌در‌توی
                                    // ارگانیک که درون جوهر جا می‌افتند
                                    Transform.scale(
                                      scale: 1.0 + _hold.value * 0.08,
                                      child: SizedBox(
                                        width: scanner * 0.66,
                                        height: scanner * 0.66,
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
                  // شیشه‌ایِ لطیف تا خوانا ولی نامحسوس بماند
                  Positioned(
                    top: centerY + scanner / 2 + 14,
                    right: 0,
                    left: 0,
                    child: Center(
                      child: GlassPanel(
                        radius: 14,
                        blur: 10,
                        tintOpacity: 0.45,
                        borderOpacity: 0.18,
                        shadowOpacity: 0.12,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        child: Text(
                          'انگشت خود را روی اثر انگشت نگه دارید',
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: vazirText(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3F2710),
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

    // هالهٔ نرم زیر قوس (لطیف، تا جوهر ستارهٔ صحنه باقی بماند)
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 2.3
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.3)
      ..color = _gold.withOpacity(0.35 * progress);
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

/// قطرهٔ جوهرِ سرخ که با لمس ظاهر می‌شود و هم‌زمان با نگه‌داشتن انگشت
/// بزرگ و بزرگ‌تر می‌شود تا دور اثر انگشت را بگیرد؛ لبه‌های نامنظمِ
/// ارگانیک، پاشش‌های ریز اطراف و برقِ مرطوبِ جوهر را شبیه‌سازی می‌کند.
class _InkBloomPainter extends CustomPainter {
  const _InkBloomPainter({required this.progress});

  /// قرمزِ جوهرِ لاکی (هم‌خانوادهٔ رنگِ اثر انگشتِ سنتی روی سربوم)
  static const _ink = Color(0xFF7C2015);

  final double progress;

  static double _smooth(double t) => t * t * (3 - 2 * t);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.003) return;

    final center = size.center(Offset.zero);
    // گسترش با شتابِ اولیه که نرم جا می‌افتد (حسِ جذب‌شدن جوهر در کاغذ)
    final inv = 1 - progress;
    final ease = 1 - inv * inv * inv;
    final maxR = size.width * 0.46;
    var r = size.width * 0.06 + (maxR - size.width * 0.06) * ease;
    // ضربهٔ پایانیِ لحظهٔ تکمیل
    if (progress > 0.9) r *= 1 + 0.05 * _smooth((progress - 0.9) / 0.1);
    // لبهٔ جوهر: لوبه‌دار و ارگانیک؛ با جاافتادن، صاف‌تر و دایره‌ای‌تر می‌شود
    final wobbleAmp = 0.26 - 0.16 * ease;

    final path = Path();
    final phase = progress * 1.6; // چرخشِ بسیار آرامِ لوب‌ها
    const steps = 72;
    for (var s = 0; s <= steps; s++) {
      final theta = s / steps * 2 * math.pi;
      final wobble = 1 +
          wobbleAmp * math.sin(3 * theta + phase + 0.9) +
          wobbleAmp * 0.6 * math.sin(7 * theta - phase * 1.3 + 2.1) +
          wobbleAmp * 0.3 * math.sin(11 * theta + phase * 0.7);
      final rr = r * wobble;
      final x = center.dx + rr * math.cos(theta);
      final y = center.dy + rr * math.sin(theta);
      if (s == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // بدنهٔ جوهر: مرکز غلیظ‌تر، لبه با محوِ نرم (جذب در بافتِ کاغذ)
    final opacity = (progress * 2.5).clamp(0.0, 1.0);
    final gradRect = Rect.fromCircle(center: center, radius: maxR * 1.35);
    final blobPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _ink.withOpacity(0.93 * opacity),
          _ink.withOpacity(0.88 * opacity),
          _ink.withOpacity(0.70 * opacity),
        ],
        stops: const [0.0, 0.60, 1.0],
      ).createShader(gradRect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.022);
    canvas.drawPath(path, blobPaint);

    // برقِ مرطوبِ جوهر نزدیک مرکز (هایلایت نرمِ مایع)
    if (progress > 0.12) {
      final sheen = Paint()
        ..color = const Color(0xFFD98A6C).withOpacity(0.34 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.06);
      final sheenCenter =
          center.translate(-r * 0.30, -r * 0.34);
      canvas.drawOval(
        Rect.fromCenter(
          center: sheenCenter,
          width: r * 0.85,
          height: r * 0.52,
        ),
        sheen,
      );
    }

    // پاشش‌های ریزِ جوهر در اطراف که کم‌کم پدیدار می‌شوند
    for (var k = 0; k < 6; k++) {
      final thr = 0.28 + k * 0.11;
      final local = _smooth(((progress - thr) / 0.22).clamp(0.0, 1.0));
      if (local <= 0) continue;
      final angle = k * 1.07 + 0.35 * math.sin(k * 3.1 + 1.2);
      final dist =
          maxR * (0.80 + 0.42 * ((math.sin(k * 2.63 + 0.7) + 1) / 2));
      final dotR = size.width *
          0.034 *
          (0.55 + 0.45 * ((math.cos(k * 4.7 + 2.3) + 1) / 2)) *
          local;
      final dotCenter =
          center.translate(math.cos(angle) * dist, math.sin(angle) * dist);
      canvas.drawCircle(
        dotCenter,
        dotR,
        Paint()
          ..color = _ink.withOpacity((0.45 + 0.40 * local) * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotR * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_InkBloomPainter old) => old.progress != progress;
}

/// اثر انگشتِ واقع‌گرا: ده خطِ قوسیِ بیضی‌شکل و ناهمگون (مانند چین‌های
/// نوک انگشت) با گسستِ طبیعیِ جوهر و دلتای پایین-چپ؛ با پیشرفت اسکن
/// خط‌به‌خط به قرمزِ تیرهٔ جاافتاده تبدیل می‌شوند.
class _FingerprintPainter extends CustomPainter {
  const _FingerprintPainter({required this.progress});

  static const _baseRed = Color(0xFF7E2A1E);
  static const _litRed = Color(0xFF4E120B);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // فرمِ بیضیِ کشیدهٔ اثرِ واقعیِ انگشت
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(0.86, 1.0);
    canvas.translate(-center.dx, -center.dy);

    final stroke = size.width * 0.030;
    final ridgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const ridges = 10;
    for (var i = 0; i < ridges; i++) {
      final t = i / (ridges - 1); // 0 بیرونی‌ترین → 1 درونی‌ترین
      final r = size.width * (0.46 - 0.379 * t);
      if (r <= stroke * 2) break;
      final rect = Rect.fromCircle(center: center, radius: r);
      // خطوط بیرونی تقریباً بسته، خطوط داخلی به‌سوی دلتای پایین بازتر
      final sweep = math.pi * (1.92 - 0.72 * t);
      final gapCenter = -math.pi * (0.48 + 0.18 * math.sin(i * 1.7));
      final start = gapCenter - sweep / 2;
      // ناهمسانیِ طبیعیِ جوهر (قطعی و تکرارپذیر برای ثباتِ ظاهر)
      final jitter = 0.78 + 0.22 * (math.sin(i * 2.39 + 1.7)).abs();
      final reveal = (progress * (ridges + 2) - i * 0.85).clamp(0.0, 1.0);
      final col = Color.lerp(_baseRed.withOpacity(0.30), _litRed, reveal)!;
      ridgePaint.color = col.withAlpha((col.alpha * jitter).round());

      if (i % 3 != 0) {
        // گسستِ میانیِ بعضی خطوط برای حسِ جوهرِ واقعی
        final frac = 0.34 + 0.28 * ((math.sin(i * 5.13) + 1) / 2);
        final mid = 0.055 + 0.09 * ((math.cos(i * 3.7) + 1) / 2);
        canvas.drawArc(rect, start, sweep * (frac - mid / 2), false, ridgePaint);
        canvas.drawArc(rect, start + sweep * (frac + mid / 2),
            sweep * (1 - frac - mid / 2), false, ridgePaint);
      } else {
        canvas.drawArc(rect, start, sweep, false, ridgePaint);
      }
    }

    // قلبِ اثر انگشت: هستهٔ مرکزی + حلقهٔ ریزِ دور آن
    final coreReveal =
        (progress * (ridges + 2) - ridges).clamp(0.0, 1.0);
    final coreCol =
        Color.lerp(_baseRed.withOpacity(0.30), _litRed, coreReveal)!;
    canvas.drawCircle(center, stroke * 1.05, Paint()..color = coreCol);
    final coreRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.9
      ..strokeCap = StrokeCap.round
      ..color = coreCol;
    canvas.drawArc(Rect.fromCircle(center: center, radius: stroke * 2.4),
        -math.pi * 0.6, math.pi * 1.45, false, coreRing);

    // ذرات ریزِ جوهرِ پاشیده‌شده نزدیک مرکز
    final speckAlpha = (140 * (0.3 + 0.7 * coreReveal)).round();
    final speck = Paint()..color = _litRed.withAlpha(speckAlpha);
    canvas
      ..drawCircle(center.translate(size.width * 0.10, -size.width * 0.07),
          stroke * 0.42, speck)
      ..drawCircle(center.translate(-size.width * 0.09, size.width * 0.11),
          stroke * 0.36, speck)
      ..drawCircle(center.translate(size.width * 0.05, size.width * 0.14),
          stroke * 0.30, speck);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FingerprintPainter old) => old.progress != progress;
}
