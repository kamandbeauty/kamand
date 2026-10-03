import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/poem.dart';
import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/poem_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// صفحهٔ «اشعار دلخواه» - شعرهایی که کاربر نشان کرده است
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const Color _accent = Color.fromRGBO(234, 158, 77, 1);
  static const Color _dark = Color.fromRGBO(107, 38, 15, 1);

  SettingsService get _settings => Get.find<SettingsService>();

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
                      'اشعار دلخواه',
                      style: vazirText(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: Get.back,
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
                        child: const Icon(CupertinoIcons.back, color: _dark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // فهرست دلخواه‌ها - با تغییر تنظیمات زنده به‌روز می‌شود
              Expanded(
                child: AnimatedBuilder(
                  animation: _settings,
                  builder: (context, _) {
                    final ids = _settings.favorites.toList(growable: false);
                    return FutureBuilder<List<Poem>>(
                      future: _resolve(ids),
                      builder: (context, snapshot) {
                        final poems = snapshot.data ?? const <Poem>[];
                        if (ids.isNotEmpty && snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: _accent),
                          );
                        }
                        if (poems.isEmpty) return _emptyState();
                        return _buildList(poems, bottomPadding);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Poem>> _resolve(List<String> ids) async {
    final poems = <Poem>[];
    for (final id in ids) {
      try {
        poems.add(await DivanRepository.findById(id));
      } catch (_) {
        // شعری که دیگر در دیتاست نیست نادیده گرفته می‌شود
      }
    }
    return poems;
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.heart, color: Colors.white70, size: 64),
          const SizedBox(height: 16),
          Text(
            'هنوز شعری را دلخواه نکرده‌اید',
            textDirection: TextDirection.rtl,
            style: vazirText(
              fontSize: 17,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'در صفحهٔ خواندن شعر، روی دکمهٔ «دلخواه» بزنید',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: vazirText(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Poem> poems, double bottomPadding) {
    final ids = poems.map((p) => p.id).toList(growable: false);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView.builder(
          padding: EdgeInsets.only(
              right: 14, left: 14, bottom: bottomPadding + 14),
          itemCount: poems.length,
          itemBuilder: (context, index) {
            final poem = poems[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      Get.to(() => PoemScreen(poemId: poem.id, scopeIds: ids)),
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
                        IconButton(
                          tooltip: 'حذف از دلخواه',
                          onPressed: () => _settings.toggleFavorite(poem.id),
                          icon: const Icon(
                            CupertinoIcons.heart_slash_fill,
                            color: Color.fromRGBO(200, 60, 60, 1),
                          ),
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
