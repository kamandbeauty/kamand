import 'dart:math' as math;

import 'package:fale_hafez/data/settings_service.dart';
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

  /// نقاشِ افکتِ انتخاب‌شده برای پیشرفتِ اسکنِ اثر انگشت
  CustomPainter _bloomPainter(String effect) {
    if (effect == 'petal') {
      return PetalBloomPainter(progress: _hold.value);
    }
    return InkBloomPainter(progress: _hold.value);
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
              // جایگاه متناسب با ترکیب‌بندی اثر: روی فضای خالیِ
              // بین خوش‌نویسیِ نیّت و دیوانِ باز (پایینِ وسطِ قاب)
              final double centerY = constraints.maxHeight * 0.66;

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
                                    // افکتِ اسکن (انتخابی در تنظیمات):
                                    // پخش‌شدنِ قطرهٔ جوهر یا گلبرگ‌ها
                                    // زیر انگشت و به‌تدریج دور اثر انگشت
                                    Builder(
                                      builder: (context) {
                                        final effect = Get.find<
                                                SettingsService>()
                                            .fingerprintEffect;
                                        // گلبرگ باید تا بیرون از ناحیهٔ
                                        // اثر انگشت پخش شود؛ جوهر درون‌تر
                                        // می‌ماند (کادرِ جداکننده ندارد)
                                        final bloomSide = effect == 'petal'
                                            ? scanner * 1.30
                                            : scanner * 0.80;
                                        return SizedBox(
                                          width: bloomSide,
                                          height: bloomSide,
                                          child: CustomPaint(
                                            painter: _bloomPainter(effect),
                                          ),
                                        );
                                      },
                                    ),
                                    // اثر انگشتِ واقعی (همان thumb.jpg مرجعِ
                                    // صاحب‌اثر) با محوِ لبهٔ بیضی‌وار — بدون
                                    // قاب؛ خطوط روی سوادِ کاغذیِ روشن دیده
                                    // می‌شوند و هنگام نگه‌داشتن انگشت به
                                    // رنگ طلایی درمی‌آیند
                                    Transform.scale(
                                      scale: 1.0 + _hold.value * 0.08,
                                      child: SizedBox(
                                        width: scanner * 0.74,
                                        height: scanner * 0.74,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ShaderMask(
                                              key: const Key(
                                                  'fingerprint_print'),
                                              shaderCallback: (bounds) =>
                                                  const RadialGradient(
                                                colors: [
                                                  Colors.white,
                                                  Colors.white,
                                                  Colors.transparent,
                                                ],
                                                stops: [0.0, 0.52, 0.86],
                                              ).createShader(bounds),
                                              blendMode: BlendMode.dstIn,
                                              child: Image.asset(
                                                'assets/fingerprint.png',
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            // رنگِ طلاییِ پیشرفتِ اسکن
                                            Opacity(
                                              opacity: _hold.value,
                                              child: ShaderMask(
                                                shaderCallback: (bounds) =>
                                                    const RadialGradient(
                                                  colors: [
                                                    Colors.white,
                                                    Colors.white,
                                                    Colors.transparent,
                                                  ],
                                                  stops: [0.0, 0.52, 0.86],
                                                ).createShader(bounds),
                                                blendMode: BlendMode.dstIn,
                                                child: ColorFiltered(
                                                  colorFilter:
                                                      const ColorFilter.mode(
                                                    Color(0xFFD9A94A),
                                                    BlendMode.modulate,
                                                  ),
                                                  child: Image.asset(
                                                    'assets/fingerprint.png',
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
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


/// قطرهٔ جوهرِ سرخ که با لمس ظاهر می‌شود و هم‌زمان با نگه‌داشتن انگشت
/// بزرگ و بزرگ‌تر می‌شود تا دور اثر انگشت را بگیرد؛ لبه‌های نامنظمِ
/// ارگانیک، پاشش‌های ریز اطراف و برقِ مرطوبِ جوهر را شبیه‌سازی می‌کند.
/// (یکی از دو افکتِ قابل‌انتخاب در تنظیمات برای اسکنِ اثر انگشت)
class InkBloomPainter extends CustomPainter {
  const InkBloomPainter({required this.progress});

  /// جوهرِ مشکیِ دست‌نویسِ سنتی (مرکبِ خوش‌نویسان)
  static const _ink = Color(0xFF161310);

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
        ..color = const Color(0xFFB8B0A2).withOpacity(0.30 * opacity)
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
  bool shouldRepaint(InkBloomPainter old) => old.progress != progress;
}

/// گلبرگ‌های رز که با نگه‌داشتن انگشت یکی‌یکی پخش و بزرگ می‌شوند و
/// دور اثر انگشت را می‌گیرند — افکتِ انتخابی جایگزینِ پخش‌شدنِ جوهر.
///
/// ساختار با جوهر هماهنگ است: هر گلبرگ در آستانه‌ای از پیشرفت ظاهر
/// می‌شود، نرم بیرون می‌رود و کمی می‌چرخد؛ در مرکز، هالهٔ رز و قلبِ
/// طلایی می‌تراکم.
class PetalBloomPainter extends CustomPainter {
  const PetalBloomPainter({required this.progress});

  /// پالت گلبرگ رز (عمیق تا blush) + قلبِ طلایی هماهنگ با تمِ اپ
  static const _petalDeep = Color(0xFFB83A5C);
  static const _petalRose = Color(0xFFDF7E97);
  static const _petalBlush = Color(0xFFF4C3CE);
  static const _petalPale = Color(0xFFFADCE3);
  static const _petalCore = Color(0xFFD9A94A);

  /// تعداد گلبرگ‌های پخش‌شده در هوای کلِ کادر
  static const int _petalCount = 34;

  final double progress;

  static double _smooth(double t) => t * t * (3 - 2 * t);

  /// شبه‌تصادفیِ قطعیِ به ازای ایندکس: همان جا در همهٔ فریم‌ها —
  /// چیدمانِ پراکنده ولی هرگز بین فریم‌ها جست نمی‌کند.
  static double _rand(int index, int channel) {
    var h = index * 374761393 + channel * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return ((h ^ (h >> 16)) & 0xFFFFFF) / 0xFFFFFF;
  }

  /// رسم یک گلبرگ قطره‌ای‌شکل از [base] تا [tip] با پهنای [width].
  /// لبه‌ها با منحنی‌های cubic موجِ ارگانیک می‌گیرند.
  static Path _petalPath(Offset base, Offset tip, double width) {
    final dir = (tip - base);
    final length = dir.distance;
    if (length <= 0) return Path();
    final unit = dir / length;
    final side = Offset(-unit.dy, unit.dx);
    final p1 = base + side * (width * 0.62) + unit * (length * 0.14);
    final p2 = base + side * (width * 0.48) + unit * (length * 0.72);
    final p3 = base - side * (width * 0.48) + unit * (length * 0.72);
    final p4 = base - side * (width * 0.62) + unit * (length * 0.14);
    return Path()
      ..moveTo(base.dx, base.dy)
      ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, tip.dx, tip.dy)
      ..cubicTo(p3.dx, p3.dy, p4.dx, p4.dy, base.dx, base.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.003) return;

    final center = size.center(Offset.zero);
    final ease = 1 - (1 - progress) * (1 - progress) * (1 - progress);

    // هالهٔ رزِ نِرمِ زیر گلبرگ‌ها (کم‌رنگ‌تر و گسترده‌تر از نسخهٔ جوهر)
    final glowOpacity = (progress * 2.2).clamp(0.0, 1.0);
    final glowR = size.width * (0.42 + 0.26 * ease);
    canvas.drawCircle(
      center,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF9C2F50).withOpacity(0.24 * glowOpacity),
            const Color(0xFF9C2F50).withOpacity(0.12 * glowOpacity),
            const Color(0xFF9C2F50).withOpacity(0.0),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowR))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.04),
    );

    // قلبِ طلاییِ مرکزی — کانونِ زیر اثر انگشت که اول ظاهر می‌شود
    if (progress > 0.06) {
      final heartT = _smooth(((progress - 0.06) / 0.30).clamp(0.0, 1.0));
      canvas.drawCircle(
        center,
        size.width * 0.048 * (0.35 + 0.65 * heartT),
        Paint()
          ..color = _petalCore.withOpacity(0.85 * heartT)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.012),
      );
    }

    // پخش‌شدنِ پراکنده در سراسر کادر اثر انگشت: هر گلبرگ جایِ خاصِ
    // خودش را در هوا دارد — از کنارِ مرکز تا لبه‌های دورِ کادر؛ با
    // پیشرفت، از آستانهٔ خودش ظاهر و بزرگ می‌شود، کمی می‌چرخد و در
    // وزشِ نامنظمی چند پیکسل جابه‌جا می‌شود.
    const palette = [_petalDeep, _petalRose, _petalBlush, _petalPale];
    for (var i = 0; i < _petalCount; i++) {
      // آستانهٔ ظهورِ نامنظمِ هر گلبرگ: بعضی زود و بعضی دیرتر ظاهر می‌شوند
      final thr = 0.05 + (i / _petalCount) * 0.22 + _rand(i, 1) * 0.36;
      final local = _smooth(((progress - thr) / 0.34).clamp(0.0, 1.0));
      if (local <= 0) continue;

      final angle = _rand(i, 2) * 2 * math.pi +
          progress * 0.22 * (0.5 + _rand(i, 3));
      final distFactor = 0.06 + _rand(i, 4) * 0.93; // کنارِ مرکز تا لبهٔ کادر
      final dist = size.width * 0.5 * distFactor * (0.55 + 0.45 * ease);

      final petalLen = size.width *
          (0.034 + 0.040 * _rand(i, 5)) *
          (0.35 + 0.65 * local);
      final petalW = petalLen * (0.55 + 0.25 * _rand(i, 6));
      if (petalLen < 0.6) continue;

      // وزشِ نامنظم: شناورشدنِ چند پیکسلیِ گلبرگ در هوا (کمی به سمت بالا)
      final drift = Offset(
        (_rand(i, 7) - 0.5) * size.width * 0.06 * progress,
        (_rand(i, 8) - 0.62) * size.width * 0.07 * progress,
      );
      final base =
          center + Offset(math.cos(angle), math.sin(angle)) * dist + drift;

      // نوک گلبرگ: تقریباً به‌سمتِ بیرون از مرکز + چرخشِ مختصِ هر گلبرگ
      final tipAngle = angle +
          (_rand(i, 9) - 0.5) * 1.2 +
          progress * (0.35 + _rand(i, 10) * 0.5);
      final tip =
          base + Offset(math.cos(tipAngle), math.sin(tipAngle)) * petalLen;

      final color = palette[
          (_rand(i, 11) * palette.length).floor() % palette.length];
      final opacity = (local * 1.35).clamp(0.0, 0.92);

      canvas.drawPath(
        _petalPath(base, tip, petalW),
        Paint()..color = color.withOpacity(opacity),
      );

      // رگبرگِ ظریف در میانهٔ گلبرگ
      canvas.drawLine(
        Offset.lerp(base, tip, 0.12)!,
        Offset.lerp(base, tip, 0.88)!,
        Paint()
          ..color = Colors.white.withOpacity(opacity * 0.35)
          ..strokeWidth = (petalLen * 0.05).clamp(0.4, 1.4)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(PetalBloomPainter old) => old.progress != progress;
}
