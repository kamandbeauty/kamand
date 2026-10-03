import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// صفحهٔ تنظیمات: انتخاب قلم و اندازهٔ قلم اشعار.
/// تغییرات بلافاصله در کل برنامه اعمال و ذخیره می‌شوند.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
          child: AnimatedBuilder(
            animation: _settings,
            builder: (context, _) {
              return ListView(
                padding: EdgeInsets.only(
                  top: topPadding + 10,
                  right: 16,
                  left: 16,
                  bottom: bottomPadding + 16,
                ),
                children: [
                  // نوار بالایی: عنوان و بازگشت
                  Row(
                    children: [
                      Text(
                        'تنظیمات',
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
                  const SizedBox(height: 18),

                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionCard(
                            title: 'قلم',
                            icon: CupertinoIcons.textformat,
                            child: Column(
                              children: poemFontFamilies.keys
                                  .map(_fontOption)
                                  .toList(growable: false),
                            ),
                          ),
                          const SizedBox(height: 14),

                          _sectionCard(
                            title: 'اندازهٔ قلم اشعار',
                            icon: CupertinoIcons.textformat_size,
                            child: Column(
                              children: [
                                // پیش‌نمایش زنده
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'الا یا ایها الساقی ادر کاسا و ناولها\nبه می سجاده رنگین کن گرت پیر مغان گوید',
                                    textAlign: TextAlign.center,
                                    textDirection: TextDirection.rtl,
                                    style: vazirText(
                                      fontSize: 16 * _settings.poemScale,
                                      color: _dark,
                                      height: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      'الف',
                                      style: vazirText(
                                          fontSize: 14, color: _dark),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: _settings.poemScale,
                                        min: SettingsService.minScale,
                                        max: SettingsService.maxScale,
                                        activeColor: _accent,
                                        inactiveColor:
                                            _dark.withOpacity(0.3),
                                        onChanged: _settings.setPoemScale,
                                      ),
                                    ),
                                    Text(
                                      'الف',
                                      style: vazirText(
                                          fontSize: 24, color: _dark),
                                    ),
                                  ],
                                ),
                                Text(
                                  'برای بزرگنمایی سریع، روی متن شعر هم می‌توانید با دو انگشت جمع و باز کنید',
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  style: vazirText(
                                      fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'تغییرات بلافاصله اعمال و روی دستگاه ذخیره می‌شوند',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: vazirText(
                                fontSize: 12, color: Colors.white70),
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
    );
  }

  Widget _fontOption(String key) {
    final selected = _settings.fontKey == key;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _settings.setFont(key),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withOpacity(0.95)
              : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _dark : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              color: _dark,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poemFontLabels[key] ?? key,
                    textDirection: TextDirection.rtl,
                    style: vazirText(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'توانا بود هر که دانا بود',
                    textDirection: TextDirection.rtl,
                    style: vazirText(
                      fontSize: 13,
                      color: _dark.withOpacity(0.75),
                      fontFamily: poemFontFamily(key),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _dark),
              const SizedBox(width: 8),
              Text(
                title,
                textDirection: TextDirection.rtl,
                style: vazirText(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _dark,
                ),
              ),
            ],
          ),
          child,
        ],
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
}
