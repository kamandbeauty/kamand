import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تنظیمات کاربر: قلم، اندازهٔ قلم اشعار و فهرست اشعار دلخواه.
/// همه به‌صورت آفلاین روی دستگاه ذخیره می‌شوند.
class SettingsService extends ChangeNotifier {
  static const String _kFont = 'poem_font_key';
  static const String _kScale = 'poem_font_scale';
  static const String _kFavorites = 'poem_favorites';

  /// کمترین و بیشترین ضریب بزرگنمایی قلم اشعار
  static const double minScale = 0.7;
  static const double maxScale = 2.0;
  static const double defaultScale = 1.0;

  SharedPreferences? _prefs;

  String _fontKey = 'vazirmatn';
  double _poemScale = defaultScale;
  Set<String> _favorites = {};

  String get fontKey => _fontKey;
  double get poemScale => _poemScale;
  Set<String> get favorites => Set.unmodifiable(_favorites);

  /// خواندن تنظیمات ذخیره‌شده از حافظهٔ دستگاه
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _fontKey = _prefs!.getString(_kFont) ?? _fontKey;
    _poemScale = _prefs!.getDouble(_kScale) ?? _poemScale;
    _favorites =
        (_prefs!.getStringList(_kFavorites) ?? const <String>[]).toSet();
    notifyListeners();
  }

  bool isFavorite(String poemId) => _favorites.contains(poemId);

  /// نوشتن روی حافظهٔ دستگاه با تحمل خطا.
  ///
  /// اگر ذخیره‌سازی شکست بخورد (کمبود فضا یا خطای I/O)، مهم‌ترین چیز
  /// تجربهٔ کاربر در همین اجراست و وضعیتِ حافظهٔ درون برنامه معتبر
  /// می‌ماند؛ خطا لاگ می‌شود تا failure بی‌سروصدا از دست نرود و UI
  /// وضعیت اشتباه «حتماً ذخیره شد» را قطعی القا نکند.
  void _persist(Future<bool> Function(SharedPreferences prefs) write) {
    final prefs = _prefs;
    if (prefs == null) return;
    write(prefs).onError((Object error, StackTrace _) {
      debugPrint('SettingsService: خطا در ذخیره‌سازی تنظیمات — $error');
      return false;
    });
  }

  Future<void> setFont(String key) async {
    if (_fontKey == key) return;
    _fontKey = key;
    notifyListeners();
    _persist((prefs) => prefs.setString(_kFont, key));
  }

  Future<void> setPoemScale(double scale) async {
    final clamped = scale.clamp(minScale, maxScale).toDouble();
    if ((_poemScale - clamped).abs() < 0.001) return;
    _poemScale = clamped;
    notifyListeners();
    _persist((prefs) => prefs.setDouble(_kScale, clamped));
  }

  /// افزودن/حذف شعر از «اشعار دلخواه»
  Future<void> toggleFavorite(String poemId) async {
    if (_favorites.contains(poemId)) {
      _favorites.remove(poemId);
    } else {
      _favorites.add(poemId);
    }
    notifyListeners();
    _persist(
        (prefs) => prefs.setStringList(_kFavorites, _favorites.toList()));
  }
}
