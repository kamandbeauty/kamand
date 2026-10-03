import 'package:audioplayers/audioplayers.dart';
import 'package:fale_hafez/about.dart';
import 'package:fale_hafez/config.dart';
import 'package:fale_hafez/falscreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

/// صفحهٔ اصلی برنامه
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isCheckingConnection = false;

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

  /// بررسی اتصال اینترنت با یک درخواست سبک به سرور سرویس فال
  Future<bool> _hasInternetConnection() async {
    try {
      final response = await http
          .get(ApiConfig.pingEndpoint)
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  /// با زدن دکمهٔ فال: ابتدا اتصال اینترنت بررسی می‌شود؛
  /// در صورت اتصال وارد صفحهٔ فال و در غیر این صورت هشدار نمایش داده می‌شود.
  Future<void> _onFalButtonPressed() async {
    if (_isCheckingConnection) return;

    setState(() => _isCheckingConnection = true);
    final hasInternet = await _hasInternetConnection();
    if (!mounted) return;
    setState(() => _isCheckingConnection = false);

    if (hasInternet) {
      Get.to(const FalScreen());
    } else {
      _showNoInternetDialog();
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(32.0)),
          ),
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          title: Center(child: Image.asset('assets/wifi.png')),
          actions: [
            Center(
              child: Text(
                'لطفا از اتصال اینترنت خود مطمئن شوید',
                textAlign: TextAlign.center,
                locale: const Locale('fa'),
                textDirection: TextDirection.rtl,
                style: GoogleFonts.vazirmatn(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Center(
              child: Text(
                'همچنین در صورت روشن بودن فیلتر شکن آن را خاموش نمایید',
                textAlign: TextAlign.center,
                locale: const Locale('fa'),
                textDirection: TextDirection.rtl,
                style: GoogleFonts.vazirmatn(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.yellow,
                  backgroundColor: const Color.fromRGBO(234, 158, 77, 1),
                  shadowColor: const Color.fromRGBO(183, 116, 50, 1),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'بستن  پنجره',
                    style: GoogleFonts.vazirmatn(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: const Color.fromRGBO(107, 38, 15, 1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _playAudio();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;

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
              top: 20,
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

            // دکمهٔ گرفتن فال
            Positioned(
              bottom: 20,
              right: 5,
              left: 5,
              child: Center(
                child: ElevatedButton(
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
                    child: _isCheckingConnection
                        ? const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color.fromRGBO(107, 38, 15, 1),
                            ),
                          )
                        : Text(
                            'نیت کردم ، فالمو بگیر',
                            style: GoogleFonts.vazirmatn(
                              fontWeight: FontWeight.w700,
                              fontSize: 30,
                              color: const Color.fromRGBO(107, 38, 15, 1),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
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
