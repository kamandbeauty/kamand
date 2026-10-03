import 'package:fale_hafez/data/fal_repository.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/ghazal_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

/// فهرست کامل غزل‌های دیوان حافظ با امکان جستجو
class DivanScreen extends StatefulWidget {
  const DivanScreen({super.key});

  @override
  State<DivanScreen> createState() => _DivanScreenState();
}

class _DivanScreenState extends State<DivanScreen> {
  static const Color _accent = Color.fromRGBO(234, 158, 77, 1);
  static const Color _dark = Color.fromRGBO(107, 38, 15, 1);

  List<HafezFal> _all = const [];
  String _query = '';

  bool _isLoading = true;
  bool _hasError = false;

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

  /// غزل‌های فیلترشده بر اساس متن جستجو (متن غزل یا شمارهٔ آن)
  List<HafezFal> get _filtered {
    final q = _query.trim();
    if (q.isEmpty) return _all;
    return _all
        .where((f) => f.verses.contains(q) || f.number.toString() == q)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.viewPaddingOf(context).top;
    final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background/mainscreen.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            children: [
              // نوار بالایی: عنوان و دکمهٔ بازگشت
              Padding(
                padding: EdgeInsets.only(
                  top: topPadding + 10,
                  right: 16,
                  left: 16,
                ),
                child: Row(
                  children: [
                    Text(
                      'دیوان حافظ',
                      style: vazirText(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    _headerButton(
                      icon: CupertinoIcons.back,
                      onPressed: Get.back,
                    ),
                  ],
                ),
              ),

              // جعبهٔ جستجو
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  textDirection: TextDirection.rtl,
                  style: vazirText(color: _dark, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'جستجو در غزل‌ها (متن یا شماره غزل)...',
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: vazirText(
                      color: _dark.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    prefixIcon:
                        const Icon(CupertinoIcons.search, color: _dark),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.92),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // فهرست غزل‌ها
              Expanded(child: _buildList(bottomPadding)),
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

  Widget _buildList(double bottomPadding) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SpinKitFadingFour(color: Colors.white, size: 50),
            const SizedBox(height: 16),
            Text(
              'در حال باز کردن دیوان...',
              textDirection: TextDirection.rtl,
              style: vazirText(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
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

    final items = _filtered;

    if (items.isEmpty) {
      return Center(
        child: Text(
          'چیزی پیدا نشد',
          textDirection: TextDirection.rtl,
          style: vazirText(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ListView.separated(
      padding:
          EdgeInsets.only(right: 14, left: 14, bottom: bottomPadding + 14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final fal = items[index];
        return Material(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Get.to(() => GhazalScreen(number: fal.number)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'غزل ${fal.number}',
                          textDirection: TextDirection.rtl,
                          style: vazirText(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          fal.firstMesra,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: vazirText(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_left,
                    color: _dark.withOpacity(0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
