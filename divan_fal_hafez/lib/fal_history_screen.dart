import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/poem_screen.dart';
import 'package:fale_hafez/util/persian_text.dart';
import 'package:fale_hafez/widgets/themed_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// «دفترچهٔ فال»: تاریخچهٔ فال‌های گرفته‌شده (تازه‌ترین در بالا).
/// با لمس هر مورد، همان غزل به‌همراه تعبیر دوباره خوانده می‌شود.
class FalHistoryScreen extends StatelessWidget {
  const FalHistoryScreen({super.key});

  static const Color _accent = Color.fromRGBO(234, 158, 77, 1);
  static const Color _dark = Color.fromRGBO(107, 38, 15, 1);

  String _persianDate(DateTime dt) {
    final d =
        '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    return toPersianDigits(d);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsService>();
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
          child: AnimatedBuilder(
            animation: settings,
            builder: (context, _) {
              final entries = settings.falHistory;
              return Column(
                children: [
                  // نوار بالایی: عنوان و بازگشت
                  Padding(
                    padding: EdgeInsets.only(
                      top: topPadding + 10,
                      right: 16,
                      left: 16,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'دفترچهٔ فال',
                          style: vazirText(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ).copyWith(shadows: const [
                            Shadow(
                                color: Colors.black87,
                                blurRadius: 10,
                                offset: Offset(0, 2)),
                            Shadow(color: Colors.black45, blurRadius: 18),
                          ]),
                        ),
                        const Spacer(),
                        AppThemeButton.icon(
                          icon: CupertinoIcons.back,
                          onPressed: Get.back,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Text(
                              'هنوز فالی ثبت نشده است؛\nاز صفحهٔ اصلی فال بگیرید',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: vazirText(
                                fontSize: 17,
                                color: Colors.white,
                                height: 2,
                              ).copyWith(shadows: const [
                                Shadow(
                                    color: Colors.black87,
                                    blurRadius: 8,
                                    offset: Offset(0, 2)),
                              ]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: entries.length,
                            itemBuilder: (context, i) {
                              final entry = entries[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: Colors.white.withOpacity(0.88),
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () =>
                                        Get.to(() => PoemScreen(poemId: entry.poemId)),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.menu_book_rounded,
                                              color: _dark),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'غزل ${toPersianDigits(entry.number.toString())}',
                                              style: vazirText(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: _dark,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _persianDate(entry.occurredAt),
                                            style: vazirText(
                                              fontSize: 12,
                                              color:
                                                  _accent.withOpacity(0.9),
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
