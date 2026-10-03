import 'package:fale_hafez/data/fal_repository.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

/// صفحهٔ خواندن یک غزل از دیوان حافظ
/// + امکان مشاهدهٔ تعبیر فال همان غزل و پیمایش بین غزل‌ها
class GhazalScreen extends StatefulWidget {
  const GhazalScreen({super.key, required this.number});

  /// شمارهٔ غزل در دیوان (۱ تا ۴۹۵)
  final int number;

  @override
  State<GhazalScreen> createState() => _GhazalScreenState();
}

class _GhazalScreenState extends State<GhazalScreen> {
  static const Color _accent = Color.fromRGBO(234, 158, 77, 1);
  static const Color _dark = Color.fromRGBO(107, 38, 15, 1);

  List<HafezFal> _all = const [];
  int _index = 0;

  bool _isLoading = true;
  bool _hasError = false;
  bool _showMeaning = false;

  HafezFal? get _fal => _all.isEmpty ? null : _all[_index];

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final fals = await FalRepository.all();
      if (!mounted) return;
      setState(() {
        _all = fals;
        _index = (widget.number - 1).clamp(0, fals.length - 1);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// رفتن به غزل قبلی یا بعدی
  void _goTo(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _all.length) return;
    setState(() {
      _index = next;
      _showMeaning = false;
    });
  }

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
              image: AssetImage('assets/background/falscreen.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            children: [
              // نوار بالایی: بازگشت + لوگو
              Padding(
                padding: EdgeInsets.only(
                  top: topPadding + 10,
                  right: 14,
                  left: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('assets/logotext.png', width: width / 2.6),
                    _headerButton(
                      icon: CupertinoIcons.back,
                      onPressed: Get.back,
                    ),
                  ],
                ),
              ),

              // محتوای اصلی
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
    return SizedBox(
      width: 36,
      height: 36,
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

  Widget _buildBody(double width) {
    if (_isLoading) {
      return const Center(
        child: SpinKitFadingFour(color: Colors.white, size: 50),
      );
    }

    if (_hasError || _fal == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 50),
            const SizedBox(height: 16),
            Text(
              'خطا در باز کردن دیوان',
              textDirection: TextDirection.rtl,
              style: vazirText(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              child: Text(
                'تلاش مجدد',
                style: vazirText(color: _dark, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    final fal = _fal!;

    return Column(
      children: [
        Text(
          'غزل ${fal.number}',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: vazirText(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),

        // متن غزل
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    fal.verses,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: vazirText(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 2.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // دکمهٔ مشاهده/پنهان‌کردن تعبیر فال
                ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => _showMeaning = !_showMeaning),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.yellow,
                    backgroundColor: _accent,
                    shadowColor: const Color.fromRGBO(183, 116, 50, 1),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    _showMeaning
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.book,
                    color: _dark,
                  ),
                  label: Text(
                    _showMeaning ? 'بستن تعبیر فال' : 'مشاهدهٔ تعبیر فال',
                    style: vazirText(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _dark,
                    ),
                  ),
                ),

                // تعبیر فال
                if (_showMeaning)
                  Container(
                    width: width / 1.12,
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      fal.meaning,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: vazirText(
                        fontSize: 15,
                        color: _dark,
                        height: 1.9,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // پیمایش غزل قبلی/بعدی
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _navButton(
                  label: 'غزل بعدی',
                  icon: CupertinoIcons.chevron_right,
                  enabled: _index < _all.length - 1,
                  onPressed: () => _goTo(1),
                ),
                const SizedBox(width: 14),
                _navButton(
                  label: 'غزل قبلی',
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
  }

  Widget _navButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.yellow,
        backgroundColor: _accent,
        disabledBackgroundColor: Colors.white38,
        shadowColor: const Color.fromRGBO(183, 116, 50, 1),
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(icon, color: _dark, size: 18),
      label: Text(
        label,
        style: vazirText(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: _dark,
        ),
      ),
    );
  }
}
