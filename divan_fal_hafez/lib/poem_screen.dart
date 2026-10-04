import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/poem.dart';
import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/widgets/app_brand.dart';
import 'package:fale_hafez/widgets/glass_button.dart';
import 'package:fale_hafez/widgets/glass_panel.dart';
import 'package:fale_hafez/widgets/themed_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

/// صفحهٔ خواندن یک شعر از دیوان حافظ
///
/// امکانات: نمایش تعبیر فال (برای غزلیات)، اشتراک‌گذاری، کپی،
/// افزودن به «اشعار دلخواه»، بزرگنمایی متن با دو انگشت،
/// و پیمایش شعر قبلی/بعدی در همان فهرست.
class PoemScreen extends StatefulWidget {
  const PoemScreen({
    super.key,
    required this.poemId,
    this.category,
    this.scopeIds,
  });

  /// شناسهٔ شعری که باید نمایش داده شود
  final String poemId;

  /// بخشی که پیمایش قبلی/بعدی در آن انجام می‌شود
  /// (null یعنی کل دیوان)
  final PoemCategory? category;

  /// فهرست سفارشی شناسه‌ها برای پیمایش (مثلاً نتیجهٔ جستجو یا علاقه‌مندی‌ها)
  final List<String>? scopeIds;

  @override
  State<PoemScreen> createState() => _PoemScreenState();
}

class _PoemScreenState extends State<PoemScreen> {
  static const Color _accent = Color.fromRGBO(234, 158, 77, 1);
  static const Color _dark = Color.fromRGBO(107, 38, 15, 1);

  SettingsService get _settings => Get.find<SettingsService>();

  final Map<String, Poem> _byId = {};
  List<String> _ids = const [];
  int _index = 0;

  bool _isLoading = true;
  bool _hasError = false;
  bool _showMeaning = false;

  /// بزرگنمایی موقت هنگام ژست دو انگشتی
  double? _transientScale;
  double _gestureBase = SettingsService.defaultScale;

  Poem? get _poem => _ids.isEmpty ? null : _byId[_ids[_index]];

  double get _fontScale =>
      (_transientScale ?? _settings.poemScale)
          .clamp(SettingsService.minScale, SettingsService.maxScale)
          .toDouble();

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final all = await DivanRepository.all();
      if (!mounted) return;

      for (final poem in all) {
        _byId[poem.id] = poem;
      }

      final scope = widget.scopeIds;
      if (scope != null && scope.isNotEmpty) {
        _ids = scope.where(_byId.containsKey).toList(growable: false);
      } else if (widget.category != null) {
        _ids = all
            .where((p) => p.category == widget.category)
            .map((p) => p.id)
            .toList(growable: false);
      } else {
        _ids = all.map((p) => p.id).toList(growable: false);
      }

      var index = _ids.indexOf(widget.poemId);
      if (index < 0) index = 0;

      setState(() {
        _index = index;
        _isLoading = false;
        _hasError = _ids.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// رفتن به شعر قبلی یا بعدی در فهرست
  void _goTo(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _ids.length) return;
    setState(() {
      _index = next;
      _showMeaning = false;
      _transientScale = null;
    });
  }

  // ---- اشتراک‌گذاری و کپی ----

  String _shareText(Poem poem, {bool includeMeaning = false}) {
    final buffer = StringBuffer('${poem.displayTitle}\n\n${poem.verses}');
    if (includeMeaning && poem.meaning != null) {
      buffer.write('\n\nتعبیر فال: ${poem.meaning}');
    }
    buffer.write('\n\n— اپلیکیشن «دیوان و فال حافظ»');
    return buffer.toString();
  }

  Future<void> _sharePoem(Poem poem) =>
      Share.share(_shareText(poem, includeMeaning: _showMeaning));

  Future<void> _copyPoem(Poem poem) async {
    await Clipboard.setData(
        ClipboardData(text: _shareText(poem, includeMeaning: _showMeaning)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _dark,
        content: Text(
          'شعر در حافظه کپی شد',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: vazirText(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---- بزرگنمایی با دو انگشت ----

  void _onScaleStart(ScaleStartDetails details) {
    // مبنا، مقیاسِ جاریِ اعمال‌شده است (نه مقدار ذخیره‌شدهٔ قدیمی) تا
    // دومین ژستِ پیاپی پرش نداشته باشد
    _gestureBase = _fontScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // با یک انگشت (اسکرول معمولی) مقیاس تغییر نمی‌کند؛ وقتی یکی از دو
    // انگشت برداشته شود، آخرین مقدار تا onScaleEnd نگه داشته می‌شود و
    // همان‌جا نهایی می‌گردد (باگ ماندگاری حالت موقت)
    if (details.pointerCount < 2) return;
    setState(() {
      _transientScale = (_gestureBase * details.scale)
          .clamp(SettingsService.minScale, SettingsService.maxScale)
          .toDouble();
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final scale = _transientScale;
    if (scale != null) {
      // ابتدا مقدار نهایی در تنظیمات اعمال می‌شود (بخش همگامش بلافاصله
      // notify می‌کند) و سپس حالت موقت پاک می‌گردد تا متن هرگز به
      // اندازهٔ قبلی برنگردد
      _settings.setPoemScale(scale);
    }
    if (mounted) setState(() => _transientScale = null);
  }

  // نکته: onScaleCancel در GestureDetectorِ SDKهای قدیمی‌تر وجود ندارد؛
  // مدیریت حالت موقت فقط با ژست‌های start/update/end انجام می‌شود و
  // مقدار موقت همواره بعد از پایان ژست با مقدار ذخیره‌شده جایگزین می‌گردد.

  @override
  void initState() {
    super.initState();
    _load();
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
              image: AssetImage('assets/background/poems.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            children: [
              // نوار بالایی: لوگو + بازگشت
              Padding(
                padding: EdgeInsets.only(
                  top: topPadding + 10,
                  right: 14,
                  left: 14,
                ),
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
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AppBrand(fontSize: 18, onDark: false),
                      ),
                      const SizedBox(width: 12),
                      _headerButton(
                        icon: CupertinoIcons.back,
                        onPressed: Get.back,
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(child: _buildBody(width)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return AppThemeButton.icon(icon: icon, onPressed: onPressed);
  }

  Widget _buildBody(double width) {
    if (_isLoading) {
      return const Center(
        child: SpinKitFadingFour(color: _dark, size: 50),
      );
    }

    if (_hasError || _poem == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: _dark, size: 50),
            const SizedBox(height: 16),
            Text(
              'خطا در باز کردن دیوان',
              textDirection: TextDirection.rtl,
              style: vazirText(
                fontSize: 16,
                color: _dark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              style: AppThemeButton.style(),
              child: Text(
                'تلاش مجدد',
                style: vazirText(
                    color: AppThemeButton.gold, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    final poem = _poem!;

    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        // مقیاس قلم «داخل» builder محاسبه می‌شود تا با هر تغییر در
        // SettingsService (اسلایدر تنظیمات یا ذخیرهٔ زوم دو انگشتی)
        // همان فریم با مقدار تازه رسم شود — نه مقدار کهنهٔ بیرونی
        final fontScale = _fontScale;
        final isFav = _settings.isFavorite(poem.id);
        return Column(
          children: [
            // متن شعر + بزرگنمایی دو انگشتی
            Expanded(
              child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: GlassPanel(
                              tintOpacity: 0.42,
                              borderOpacity: 0.60,
                              radius: 20,
                              blur: 16,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 26, vertical: 28),
                              child: Column(
                                children: [
                                  Text(
                                    poem.displayTitle,
                                    textAlign: TextAlign.center,
                                    textDirection: TextDirection.rtl,
                                    style: vazirText(
                                      fontSize: 21,
                                      color: _dark,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 1.4,
                                    width: 120,
                                    color:
                                        _dark.withOpacity(0.35),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    poem.verses,
                                    textAlign: TextAlign.center,
                                    textDirection: TextDirection.rtl,
                                    style: vazirText(
                                      fontSize: 17 * fontScale,
                                      color: _dark,
                                      fontWeight: FontWeight.w700,
                                      height: 2.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // دکمهٔ تعبیر فال (فقط غزلیات) - شیشه‌ای
                          if (poem.meaning != null)
                            GlassButton(
                              onPressed: () => setState(
                                  () => _showMeaning = !_showMeaning),
                              icon: _showMeaning
                                  ? CupertinoIcons.eye_slash
                                  : CupertinoIcons.book,
                              label: _showMeaning
                                  ? 'بستن تعبیر فال'
                                  : 'مشاهدهٔ تعبیر فال',
                              expand: false,
                              tint: _accent,
                              tintOpacity: 0.32,
                              borderOpacity: 0.55,
                              textColor: _dark,
                              iconColor: _dark,
                              fontSize: 16,
                              height: 54,
                              radius: 14,
                            ),

                          // تعبیر فال
                          if (_showMeaning && poem.meaning != null)
                            Container(
                              width: width / 1.12,
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.92),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                poem.meaning!,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: vazirText(
                                  fontSize: 15 * fontScale,
                                  color: _dark,
                                  height: 1.9,
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // دکمه‌های اشتراک، کپی و دلخواه
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _actionButton(
                                icon: CupertinoIcons.share,
                                label: 'اشتراک‌گذاری',
                                onPressed: () => _sharePoem(poem),
                              ),
                              const SizedBox(width: 10),
                              _actionButton(
                                icon: CupertinoIcons.doc_on_clipboard,
                                label: 'کپی',
                                onPressed: () => _copyPoem(poem),
                              ),
                              const SizedBox(width: 10),
                              _actionButton(
                                icon: isFav
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                label: isFav ? 'حذف دلخواه' : 'دلخواه',
                                color: isFav
                                    ? const Color.fromRGBO(255, 120, 120, 1)
                                    : null,
                                onPressed: () =>
                                    _settings.toggleFavorite(poem.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // پیمایش شعر قبلی/بعدی
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _navButton(
                      label: 'بعدی',
                      icon: CupertinoIcons.chevron_right,
                      enabled: _index < _ids.length - 1,
                      onPressed: () => _goTo(1),
                    ),
                    const SizedBox(width: 14),
                    _navButton(
                      label: 'قبلی',
                      icon: CupertinoIcons.chevron_left,
                      enabled: _index > 0,
                      onPressed: () => _goTo(-1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final resolved = color ?? _dark;
    return GlassButton(
      onPressed: onPressed,
      icon: icon,
      iconSize: 18,
      label: label,
      expand: false,
      tint: _accent,
      tintOpacity: 0.28,
      borderOpacity: 0.5,
      textColor: resolved,
      iconColor: resolved,
      fontSize: 13,
      height: 48,
      radius: 12,
    );
  }

  Widget _navButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return GlassButton(
      onPressed: enabled ? onPressed : null,
      icon: icon,
      iconSize: 18,
      label: label,
      expand: false,
      tint: _accent,
      tintOpacity: 0.30,
      borderOpacity: 0.5,
      textColor: _dark,
      iconColor: _dark,
      fontSize: 14,
      height: 48,
      radius: 12,
    );
  }
}
