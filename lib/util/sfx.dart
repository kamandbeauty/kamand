/// پخشِ افکت‌های صوتیِ کوتاهِ بازی (پخشِ ورق، انداختنِ ورق، کلیک، بردِ دست).
///
/// همهٔ فراخوانی‌ها «بی‌خطر» هستند: اگر پلاگینِ صدا در دسترس نباشد (مثلاً در
/// تست‌ها) هیچ استثنایی به بیرون درز نمی‌کند.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum Sfx { deal, play, click, win }

class SoundPlayer {
  SoundPlayer._();

  static const Map<Sfx, String> _assets = <Sfx, String>{
    Sfx.deal: 'sounds/deal.wav',
    Sfx.play: 'sounds/play.wav',
    Sfx.click: 'sounds/click.wav',
    Sfx.win: 'sounds/win.wav',
  };

  static const Map<Sfx, double> _volumes = <Sfx, double>{
    Sfx.deal: 0.75,
    Sfx.play: 0.9,
    Sfx.click: 0.35,
    Sfx.win: 0.7,
  };

  /// در تست‌ها خاموش می‌شود تا کانالِ پلاگین صدا زده نشود.
  static bool disabled = false;

  static final List<AudioPlayer> _pool = <AudioPlayer>[];
  static int _next = 0;
  static bool _ready = false;

  static void _init() {
    if (_ready || disabled) return;
    _ready = true;
    try {
      for (int i = 0; i < 4; i++) {
        final AudioPlayer p = AudioPlayer(playerId: 'shelem_sfx_$i');
        p.setReleaseMode(ReleaseMode.stop);
        p.setPlayerMode(PlayerMode.lowLatency);
        _pool.add(p);
      }
    } catch (e) {
      debugPrint('sfx init failed: $e');
      disabled = true;
    }
  }

  /// پخشِ یک افکت؛ اگر `enabled` خاموش باشد کاری نمی‌کند.
  static void play(Sfx sound, {bool enabled = true}) {
    if (!enabled || disabled) return;
    _init();
    if (_pool.isEmpty) return;
    final AudioPlayer p = _pool[_next % _pool.length];
    _next++;
    try {
      p.stop().catchError((Object _) {});
      p
          .play(
            AssetSource(_assets[sound]!),
            volume: _volumes[sound] ?? 0.8,
          )
          .catchError((Object e) {
        debugPrint('sfx play failed: $e');
      });
    } catch (e) {
      debugPrint('sfx play failed: $e');
    }
  }

  static void disposeAll() {
    for (final AudioPlayer p in _pool) {
      try {
        p.dispose();
      } catch (_) {}
    }
    _pool.clear();
    _ready = false;
  }
}
