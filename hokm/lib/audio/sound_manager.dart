import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// مدیر صدا — تمام افکت‌های صوتی و موسیقی پس‌زمینه از اینجا عبور می‌کند.
///
/// * صداها WAV کوتاه‌اند و در assets/audio/ قرار دارند.
/// * [enabled] از تنظیمات می‌آید؛ خاموش‌بودن یعنی هیچ پخشی رخ ندهد.
/// * موسیقی پس‌زمینه جدا با [musicOn] کنترل می‌شود.
/// * با رفتن اپ به پس‌زمینه، موسیقی مکث می‌کند و با بازگشت ادامه می‌یابد
///   ([handleAppPaused] / [handleAppResumed]).
class SoundManager {
  SoundManager._();

  static final SoundManager instance = SoundManager._();

  bool enabled = true;
  bool musicOn = true;

  static const String _musicFile = 'music_ambient.wav';
  bool _musicPlaying = false;
  bool _cacheWarmed = false;

  /// اگر قبل از رفتن اپ به پس‌زمینه موسیقی پخش می‌شد، با بازگشت ادامه می‌دهیم.
  bool _resumeMusicOnForeground = false;

  static const List<String> _sfx = <String>[
    'card_pick.wav',
    'card_place.wav',
    'shuffle.wav',
    'deal.wav',
    'trick_win.wav',
    'button.wav',
    'hukum.wav',
    'round_win.wav',
    'match_win.wav',
    'match_lose.wav',
  ];

  /// پیش‌بارگذاری فایل‌ها برای اولین پخش بدون تأخیر.
  Future<void> warmUp() async {
    if (_cacheWarmed) return;
    _cacheWarmed = true;
    try {
      await FlameAudio.audioCache.loadAll([..._sfx, _musicFile]);
    } on Object catch (e) {
      // نبود فایل صدا نباید بازی را متوقف کند.
      debugPrint('SoundManager warmUp failed: $e');
    }
  }

  /// مصرف حتمی خطای Future پخش — تا پخش ناموفق هیچ‌وقت
  /// به unhandled error تبدیل نشود (مهم در release و تست).
  void _consume(Future<dynamic> future, String what) {
    future.then(
      (_) {},
      onError: (Object e, StackTrace st) =>
          debugPrint('SoundManager $what failed: $e'),
    );
  }

  void _play(String file, {double volume = 1.0}) {
    if (!enabled) return;
    try {
      _consume(FlameAudio.play(file, volume: volume), 'play $file');
    } on Object catch (e) {
      debugPrint('SoundManager play $file failed: $e');
    }
  }

  // --- افکت‌ها ---

  void cardPick() => _play('card_pick.wav', volume: 0.7);
  void cardPlace() => _play('card_place.wav');
  void shuffle() => _play('shuffle.wav');
  void deal() => _play('deal.wav', volume: 0.85);
  void trickWin() => _play('trick_win.wav', volume: 0.9);
  void button() => _play('button.wav', volume: 0.7);
  void hukumSelected() => _play('hukum.wav');
  void roundWin() => _play('round_win.wav');
  void matchWin() => _play('match_win.wav');
  void matchLose() => _play('match_lose.wav');

  // --- موسیقی ---

  void startMusic() {
    if (!musicOn || _musicPlaying) return;
    _musicPlaying = true;
    try {
      _consume(FlameAudio.bgm.play(_musicFile, volume: 0.35), 'music');
    } on Object catch (e) {
      debugPrint('SoundManager music failed: $e');
      _musicPlaying = false;
    }
  }

  void stopMusic() {
    if (!_musicPlaying) return;
    _musicPlaying = false;
    _resumeMusicOnForeground = false;
    _consume(FlameAudio.bgm.stop(), 'stop music');
  }

  /// هم‌گام‌سازی با تنظیمات.
  void syncMusic() {
    if (musicOn) {
      startMusic();
    } else {
      stopMusic();
    }
  }

  // --- چرخهٔ عمر اپلیکیشن ---

  /// اپ به پس‌زمینه رفت — موسیقی را (موقتاً) مکث کن تا صدا نماند.
  void handleAppPaused() {
    if (!_musicPlaying) return;
    _resumeMusicOnForeground = true;
    _consume(FlameAudio.bgm.pause(), 'pause music');
  }

  /// اپ به پیش‌زمینه برگشت — موسیقی را اگر پخش می‌شد ادامه بده.
  void handleAppResumed() {
    if (!_resumeMusicOnForeground) return;
    _resumeMusicOnForeground = false;
    if (!musicOn) return;
    _consume(FlameAudio.bgm.resume(), 'resume music');
  }
}
