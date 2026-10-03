import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/poem.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/poem_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

/// دیوان حافظ: فهرست کامل آثار (غزلیات، رباعیات، قطعات، قصاید،
/// منتسبات و مثنویات) با جستجو در کل مجموعه و فیلتر بخش‌ها.
class DivanScreen extends StatefulWidget {
  const DivanScreen({super.key});

  @override
  State<DivanScreen> createState() => _DivanScreenState();
}

class _DivanScreenState extends State<DivanScreen> {
  static const Color _accent = Color.fromRGBO(234, 158, 77, 1);
  static const Color _dark = Color.fromRGBO(107, 38, 15, 1);

  List<Poem> _all = const [];
  String _query = '';
  PoemCategory? _selectedCategory; // null = همهٔ بخش‌ها

  bool _isLoading = true;
  bool _hasError = false;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final poems = await DivanRepository.all();
      if (!mounted) return;
      setState(() {
        _all = poems;
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

  /// اشعار فیلترشده بر اساس بخش انتخابی و متن جستجو
  List<Poem> get _filtered {
    final q = _query.trim();
    return _all.where((p) {
      if (_selectedCategory != null && p.category != _selectedCategory) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.verses.contains(q) ||
          p.displayTitle.contains(q) ||
          p.number.toString() == q;
    }).toList(growable: false);
  }

  /// تعداد اشعار هر بخش (برای روی چیپ‌ها)
  int _countOf(PoemCategory c) =>
      _all.where((p) => p.category == c).length;

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

              // جعبهٔ جستجو در کل مجموعه
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  textDirection: TextDirection.rtl,
                  style: vazirText(color: _dark, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'جستجو در کل دیوان...',
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

              // چیپ‌های بخش‌های دیوان
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _categoryChip(null, 'همه', _all.length),
                    ...PoemCategory.values.map(
                      (c) => _categoryChip(
                        c,
                        c.sectionTitle,
                        _countOf(c),
                      ),
                    ),
                  ],
                ),
              ),

              // فهرست اشعار
              Expanded(child: _buildList(bottomPadding)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(PoemCategory? category, String label, int count) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        backgroundColor: Colors.white.withOpacity(0.85),
        selectedColor: _accent,
        labelStyle: vazirText(
          color: selected ? _dark : _dark.withOpacity(0.8),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        label: Text('$label ($count)'),
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
    final scopeIds = items.map((p) => p.id).toList(growable: false);

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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView.builder(
          padding: EdgeInsets.only(
              right: 14, left: 14, bottom: bottomPadding + 14),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final poem = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Get.to(() => PoemScreen(
                        poemId: poem.id,
                        category: _selectedCategory,
                        scopeIds: scopeIds,
                      )),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                poem.displayTitle,
                                textDirection: TextDirection.rtl,
                                style: vazirText(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: _accent,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                poem.firstMesra,
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
                        // برچسب بخش (وقتی «همه» انتخاب شده)
                        if (_selectedCategory == null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              poem.category.sectionTitle,
                              textDirection: TextDirection.rtl,
                              style: vazirText(fontSize: 11, color: _dark),
                            ),
                          ),
                        Icon(
                          CupertinoIcons.chevron_left,
                          color: _dark.withOpacity(0.5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
