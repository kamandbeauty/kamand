import 'package:audioplayers/audioplayers.dart';
import 'package:fale_hafez/about.dart';
import 'package:fale_hafez/divan_screen.dart';
import 'package:fale_hafez/niyyat_screen.dart';
import 'package:fale_hafez/favorites_screen.dart';
import 'package:fale_hafez/settings_screen.dart';
import 'package:fale_hafez/widgets/app_brand.dart';
import 'package:fale_hafez/widgets/glass_button.dart';
import 'package:fale_hafez/widgets/glass_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// صفحهٔ اصلی برنامه
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;

  /// صفِ ترتیبی عملیات صوتی.
  ///
  /// همهٔ دستورهای play / stop / pause / resume به‌ترتیبِ صدورشان اجرا
  /// می‌شوند؛ بدون این صف، تغییر سریع چرخهٔ حیات (Background→Foreground)
  /// یا چند تپِ پشت‌سرهم روی دکمهٔ موسیقی می‌توانست play و stop را
  /// هم‌پوشانی (race) کند و وضعیت پخش را با _isPlaying ناهماهنگ سازد.
  Future<void> _audioChain = Future<void>.value();

  /// افزودن یک عملیات صوتی به انتهای صف؛ خطای یک عملیات، اجرای
  /// عملیات‌های بعدی صف را متوقف نمی‌کند.
  void _enqueueAudio(Future<void> Function() operation) {
    _audioChain = _audioChain
        .then((_) => operation())
        .onError((Object error, StackTrace _) =>
            debugPrint('عملیات صوتی ناموفق: $error'));
  }

  /// آیا هنگام بازگشت از پس‌زمینه، موسیقی باید ادامه پیدا کند؟
  bool _resumeMusicOnForeground = false;

  /// پخش آفلاین آهنگ حافظ از فایل داخل برنامه (بدون نیاز به اینترنت)
  void _playAudio() => _enqueueAudio(() async {
        try {
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.play(AssetSource('background/hafez.mp3'));
          if (mounted) setState(() => _isPlaying = true);
        } catch (_) {
          if (mounted) setState(() => _isPlaying = false);
        }
      });

  void _stopAudio() => _enqueueAudio(() async {
        try {
          await _audioPlayer.stop();
        } finally {
          if (mounted) setState(() => _isPlaying = false);
        }
      });

  /// رفتن به صفحهٔ نیّت - متن آیین نیّت و سپس نگه‌داشتن انگشت
  /// روی اثر انگشت برای گرفتن فال (فال‌ها آفلاین و داخل برنامه‌اند)
  void _onFalButtonPressed() => Get.to(const NiyyatScreen());

  /// رفتن به دیوان حافظ - فهرست کامل آثار با جستجو
  void _onDivanButtonPressed() => Get.to(const DivanScreen());

  /// رفتن به اشعار دلخواه و تنظیمات
  void _onFavoritesButtonPressed() => Get.to(const FavoritesScreen());

  void _onSettingsButtonPressed() => Get.to(const SettingsScreen());

  /// موقعیت پخش هنگام رفتن به پس‌زمینه ذخیره می‌شود تا
  /// با بازگشت کاربر از همان‌جا ادامه پیدا کند.
  Duration? _savedPosition;

  /// توقف کامل در پس‌زمینه (نه pause!):
  /// چون پلاگین بعد از pause فوکوس صوتی را نگه می‌دارد و هنگام بازگشت
  /// فوکوس (مثلاً بعد از پخش صدای اپ‌های دیگر) پخش را خودکار از سر می‌گیرد
  /// — همان باگی که باعث می‌شد موسیقی در حالت مینیمایز نواخته شود.
  /// اجرایش همیشه از طریق صفِ صوتی تا با resume بالقوه هم‌پوشانی نشود.
  void _pauseAudio() => _enqueueAudio(() async {
        try {
          _savedPosition = await _audioPlayer.getCurrentPosition();
          await _audioPlayer.stop(); // رهاسازی کامل فوکوس و مدیا‌سیشن
        } catch (_) {}
      });

  /// ادامهٔ پخش از موقعیت ذخیره‌شده بعد از بازگشت به اپ؛
  /// چون از طریق همان صف اجرا می‌شود، تضمین می‌شود کاملاً بعد از
  /// توقفِ پس‌زمینه انجام شود (بدون race).
  void _resumeAudio() => _enqueueAudio(() async {
        try {
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.play(AssetSource('background/hafez.mp3'));
          final pos = _savedPosition;
          _savedPosition = null;
          if (pos != null && pos > Duration.zero) {
            await _audioPlayer.seek(pos);
          }
        } catch (_) {}
      });

  /// با رفتن برنامه به پس‌زمینه موسیقی متوقف و
  /// با بازگشت کاربر (اگر خودش قطعش نکرده باشد) ادامه پیدا می‌کند.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _resumeMusicOnForeground = _isPlaying;
      if (_isPlaying) _pauseAudio();
    } else if (state == AppLifecycleState.resumed) {
      if (_resumeMusicOnForeground) {
        _resumeMusicOnForeground = false;
        _resumeAudio();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playAudio();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.viewPaddingOf(context).top;
    final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: Center(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background/homebg.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // نوار بالایی: دکمهٔ موسیقی، عنوان برند و دربارهٔ ما
            Positioned(
              top: topPadding + 12,
              right: 15,
              left: 15,
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                radius: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GlassCircleButton(
                      onPressed: _isPlaying ? _stopAudio : _playAudio,
                      icon: _isPlaying
                          ? Icons.music_note_outlined
                          : Icons.music_off_outlined,
                    ),
                    const AppBrand(fontSize: 24, onDark: true),
                    GlassCircleButton(
                      onPressed: () => Get.to(const AboutScreen()),
                      icon: CupertinoIcons.person_alt_circle,
                    ),
                  ],
                ),
              ),
            ),

            // دکمه‌های شیشه‌ای: دیوان، گرفتن فال، دلخواه و تنظیمات
            Positioned(
              bottom: bottomPadding + 16,
              right: 14,
              left: 14,
              child: Column(
                children: [
                  // دکمهٔ دیوان حافظ
                  GlassButton(
                    onPressed: _onDivanButtonPressed,
                    icon: CupertinoIcons.book,
                    iconSize: 28,
                    label: 'دیوان حافظ',
                    fontSize: 20,
                    height: 62,
                  ),
                  const SizedBox(height: 12),

                  // دکمهٔ اصلی: گرفتن فال
                  GlassButton(
                    onPressed: _onFalButtonPressed,
                    icon: CupertinoIcons.moon_stars,
                    iconSize: 30,
                    label: 'گرفتن فال',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 74,
                    radius: 24,
                    tint: const Color.fromRGBO(234, 158, 77, 1),
                    tintOpacity: 0.34,
                    borderOpacity: 0.55,
                  ),
                  const SizedBox(height: 12),

                  // دکمه‌های اشعار دلخواه و تنظیمات
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          onPressed: _onFavoritesButtonPressed,
                          icon: CupertinoIcons.heart_fill,
                          iconSize: 24,
                          label: 'اشعار دلخواه',
                          fontSize: 15,
                          height: 52,
                          radius: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassButton(
                          onPressed: _onSettingsButtonPressed,
                          icon: CupertinoIcons.gear_alt_fill,
                          iconSize: 24,
                          label: 'تنظیمات',
                          fontSize: 15,
                          height: 52,
                          radius: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
