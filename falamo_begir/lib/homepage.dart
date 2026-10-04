import 'package:audioplayers/audioplayers.dart';
import 'package:fale_hafez/about.dart';
import 'package:fale_hafez/divan_screen.dart';
import 'package:fale_hafez/niyyat_screen.dart';
import 'package:fale_hafez/favorites_screen.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/settings_screen.dart';
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

  /// آیا هنگام بازگشت از پس‌زمینه، موسیقی باید ادامه پیدا کند؟
  bool _resumeMusicOnForeground = false;

  /// پخش آفلاین آهنگ حافظ از فایل داخل برنامه (بدون نیاز به اینترنت)
  Future<void> _playAudio() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('background/hafez.mp3'));
      if (mounted) setState(() => _isPlaying = true);
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  /// رفتن به صفحهٔ نیّت - متن آیین نیّت و سپس نگه‌داشتن انگشت
  /// روی اثر انگشت برای گرفتن فال (فال‌ها آفلاین و داخل برنامه‌اند)
  void _onFalButtonPressed() => Get.to(const NiyyatScreen());

  /// رفتن به دیوان حافظ - فهرست کامل آثار با جستجو
  void _onDivanButtonPressed() => Get.to(const DivanScreen());

  /// رفتن به اشعار دلخواه و تنظیمات
  void _onFavoritesButtonPressed() => Get.to(const FavoritesScreen());

  void _onSettingsButtonPressed() => Get.to(const SettingsScreen());

  Future<void> _pauseAudio() async {
    try {
      await _audioPlayer.pause();
    } catch (_) {}
  }

  Future<void> _resumeAudio() async {
    try {
      await _audioPlayer.resume();
    } catch (_) {}
  }

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
    final double width = MediaQuery.sizeOf(context).width;
    final double topPadding = MediaQuery.viewPaddingOf(context).top;
    final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: Center(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background/mainscreen.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // نوار بالایی: دکمهٔ موسیقی، لوگو و دربارهٔ ما
            Positioned(
              top: topPadding + 12,
              right: 15,
              left: 15,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _headerButton(
                    width: width,
                    onPressed: _isPlaying ? _stopAudio : _playAudio,
                    icon: _isPlaying
                        ? Icons.music_note_outlined
                        : Icons.music_off_outlined,
                  ),
                  Image.asset(
                    'assets/logotext.png',
                    width: width / 2,
                  ),
                  _headerButton(
                    width: width,
                    onPressed: () => Get.to(const AboutScreen()),
                    icon: CupertinoIcons.person_alt_circle,
                  ),
                ],
              ),
            ),

            // دکمه‌های دیوان حافظ و گرفتن فال
            Positioned(
              bottom: bottomPadding + 16,
              right: 5,
              left: 5,
              child: Column(
                children: [
                  // دکمهٔ دیوان حافظ
                  ElevatedButton.icon(
                    onPressed: _onDivanButtonPressed,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.yellow,
                      backgroundColor: const Color.fromRGBO(234, 158, 77, 1),
                      shadowColor: const Color.fromRGBO(183, 116, 50, 1),
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      CupertinoIcons.book,
                      color: Color.fromRGBO(107, 38, 15, 1),
                    ),
                    label: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'دیوان حافظ',
                        style: vazirText(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: const Color.fromRGBO(107, 38, 15, 1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // دکمهٔ گرفتن فال
                  ElevatedButton(
                    onPressed: _onFalButtonPressed,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.yellow,
                      backgroundColor: const Color.fromRGBO(234, 158, 77, 1),
                      shadowColor: const Color.fromRGBO(183, 116, 50, 1),
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Text(
                        'نیت کردم ، فالمو بگیر',
                        style: vazirText(
                          fontWeight: FontWeight.w700,
                          fontSize: 30,
                          color: const Color.fromRGBO(107, 38, 15, 1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // دکمه‌های اشعار دلخواه و تنظیمات
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _smallButton(
                        onPressed: _onFavoritesButtonPressed,
                        icon: CupertinoIcons.heart_fill,
                        label: 'اشعار دلخواه',
                      ),
                      const SizedBox(width: 12),
                      _smallButton(
                        onPressed: _onSettingsButtonPressed,
                        icon: CupertinoIcons.gear_alt_fill,
                        label: 'تنظیمات',
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

  Widget _smallButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.yellow,
        backgroundColor: const Color.fromRGBO(234, 158, 77, 1),
        shadowColor: const Color.fromRGBO(183, 116, 50, 1),
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: Icon(icon, color: const Color.fromRGBO(107, 38, 15, 1), size: 18),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: vazirText(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: const Color.fromRGBO(107, 38, 15, 1),
          ),
        ),
      ),
    );
  }

  Widget _headerButton({
    required double width,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: width / 10,
      height: width / 10,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.yellow,
          backgroundColor: const Color.fromRGBO(234, 158, 77, 1),
          shadowColor: const Color.fromRGBO(183, 116, 50, 1),
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          icon,
          color: const Color.fromRGBO(107, 38, 15, 1),
        ),
      ),
    );
  }
}
