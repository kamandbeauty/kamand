import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/widgets/themed_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              image: AssetImage('assets/background/homebg.jpg'),
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
                        ).copyWith(shadows: const [
                          Shadow(
                              color: Colors.black87,
                              blurRadius: 10,
                              offset: Offset(0, 2)),
                          Shadow(color: Colors.black45, blurRadius: 18),
                        ]),
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
                                    color: const Color(0xFFFDF7E7),
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

                          // پشتیبان‌گیری و انتقال داده‌ها
                          _sectionCard(
                            title: 'پشتیبان‌گیری و انتقال',
                            icon: CupertinoIcons.archivebox,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'دلخواه‌ها، یادداشت‌ها، دفترچهٔ فال، قلم و اندازهٔ قلم و ادامهٔ مطالعه را کپی کنید و روی دستگاه دیگر بازیابی کنید',
                                  style: vazirText(
                                      fontSize: 12.5,
                                      color: Colors.black54,
                                      height: 1.8),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        style: AppThemeButton.style(),
                                        onPressed: _copyBackup,
                                        child: Text(
                                          'کپی نسخهٔ پشتیبان',
                                          style: vazirText(
                                            fontSize: 12.5,
                                            color: AppThemeButton.gold,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: AppThemeButton.style(),
                                        onPressed: _restoreBackupDialog,
                                        child: Text(
                                          'بازیابی از متن',
                                          style: vazirText(
                                            fontSize: 12.5,
                                            color: AppThemeButton.gold,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
        color: const Color(0xFFF7EFDD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCFA865), width: 1),
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
    return AppThemeButton.icon(icon: icon, onPressed: onPressed);
  }

  // ---- پشتیبان‌گیری و انتقال ----

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _dark,
        content: Text(
          message,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: vazirText(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// کپی نسخهٔ پشتیبان به حافظهٔ کلیپ‌بورد (قابل نگه‌داری در هر جایی)
  Future<void> _copyBackup() async {
    final jsonText = _settings.exportBackup();
    await Clipboard.setData(ClipboardData(text: jsonText));
    if (!mounted) return;
    _snack('نسخهٔ پشتیبان کپی شد؛ آن را جایی امن نگه دارید');
  }

  /// گفت‌وگوی بازیابی: کاربر متن کپی‌شدهٔ نسخهٔ پشتیبان را جا می‌گذارد
  void _restoreBackupDialog() {
    final controller = TextEditingController();
    Get.dialog(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFFF7EDD9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'بازیابی نسخهٔ پشتیبان',
            style: vazirText(
                fontWeight: FontWeight.w900, color: _dark, fontSize: 16),
          ),
          content: TextField(
            controller: controller,
            maxLines: 6,
            style: vazirText(color: _dark, fontSize: 12, height: 1.8),
            decoration: InputDecoration(
              hintText: 'متن نسخهٔ پشتیبان را این‌جا جا (Paste) کنید…',
              hintStyle: vazirText(color: _dark.withOpacity(0.45)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text('انصراف',
                  style: vazirText(color: _dark.withOpacity(0.6))),
            ),
            ElevatedButton(
              style: AppThemeButton.style(),
              onPressed: () async {
                // وجودن: اعتبارسنجی نسخهٔ پشتیبان با دیتاست (async) و
                // فقط پس از تکمیل، جا و نتیجه اعلام می‌شود؛ در جریان
                // آن هیچ وضعیت جدیدی اعمال نشده است.
                final ok =
                    await _settings.importBackup(controller.text);
                Get.back();
                if (!mounted) return;
                _snack(ok
                    ? 'بازیابی با موفقیت انجام شد'
                    : 'متن واردشده نسخهٔ پشتیبان معتبری نیست');
              },
              child: Text(
                'بازیابی',
                style: vazirText(
                    color: AppThemeButton.gold, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }
}
