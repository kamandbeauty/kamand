import 'dart:convert';

import 'package:fale_hafez/data/poem.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// یک ورودی «دفترچهٔ فال»: کدام غزل، چه زمانی فال شده است.
class FalEntry {
  const FalEntry({
    required this.poemId,
    required this.number,
    required this.occurredAt,
  });

  factory FalEntry.fromJson(Map<String, dynamic> json) => FalEntry(
        poemId: json['id'] as String,
        number: (json['n'] as num).toInt(),
        occurredAt: DateTime.parse(json['t'] as String),
      );

  final String poemId;
  final int number;
  final DateTime occurredAt;

  Map<String, dynamic> toJson() => {
        'id': poemId,
        'n': number,
        't': occurredAt.toIso8601String(),
      };
}

/// تنظیمات کاربر: قلم، اندازهٔ قلم اشعار، اشعار دلخواه، یادداشت‌های
/// شخصی، دفترچهٔ فال، آخرین شعر خوانده‌شده، آنبوردینگ و حالت شبانه.
/// همه به‌صورت آفلاین روی دستگاه ذخیره می‌شوند.
class SettingsService extends ChangeNotifier {
  static const String _kFont = 'poem_font_key';
  static const String _kScale = 'poem_font_scale';
  static const String _kFavorites = 'poem_favorites';
  static const String _kNotes = 'poem_notes';
  static const String _kFalHistory = 'fal_history';
  static const String _kLastPoemId = 'last_poem_id';
  static const String _kNightMode = 'night_mode';

  /// کمترین و بیشترین ضریب بزرگنمایی قلم اشعار
  static const double minScale = 0.7;
  static const double maxScale = 2.0;
  static const double defaultScale = 1.0;

  /// سقف نگه‌داری ورودی‌های دفترچهٔ فال
  static const int maxFalHistory = 100;

  SharedPreferences? _prefs;

  String _fontKey = 'vazirmatn';
  double _poemScale = defaultScale;
  Set<String> _favorites = {};
  Map<String, String> _notes = {};
  List<FalEntry> _falHistory = [];
  String? _lastPoemId;
  bool _nightMode = false;

  String get fontKey => _fontKey;
  double get poemScale => _poemScale;
  Set<String> get favorites => Set.unmodifiable(_favorites);
  List<FalEntry> get falHistory => List.unmodifiable(_falHistory);
  String? get lastPoemId => _lastPoemId;
  bool get nightMode => _nightMode;

  /// خواندن تنظیمات ذخیره‌شده از حافظهٔ دستگاه
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _fontKey = _prefs!.getString(_kFont) ?? _fontKey;
    _poemScale = _prefs!.getDouble(_kScale) ?? _poemScale;
    _favorites =
        (_prefs!.getStringList(_kFavorites) ?? const <String>[]).toSet();
    _notes = _decodeNoteList(_prefs!.getStringList(_kNotes));
    _falHistory = _decodeFalHistory(_prefs!.getStringList(_kFalHistory));
    _lastPoemId = _prefs!.getString(_kLastPoemId);
    _nightMode = _prefs!.getBool(_kNightMode) ?? false;
    notifyListeners();
  }

  bool isFavorite(String poemId) => _favorites.contains(poemId);

  String? noteFor(String poemId) => _notes[poemId];

  bool get notesEmpty => _notes.isEmpty;

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

  /// ذخیرهٔ یادداشت شخصی برای یک شعر (متن خالی یعنی حذف یادداشت)
  Future<void> setNote(String poemId, String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      if (!_notes.containsKey(poemId)) return;
      _notes.remove(poemId);
    } else {
      _notes[poemId] = trimmed;
    }
    notifyListeners();
    _persist((prefs) => prefs.setStringList(
        _kNotes, _encodeNoteMap(_notes)));
  }

  /// ثبت فال تازه در «دفترچهٔ فال» (تازه‌ترین در ابتدای فهرست)
  Future<void> recordFal(Poem poem) async {
    _falHistory.insert(
      0,
      FalEntry(
          poemId: poem.id, number: poem.number, occurredAt: DateTime.now()),
    );
    if (_falHistory.length > maxFalHistory) {
      _falHistory = _falHistory.sublist(0, maxFalHistory);
    }
    notifyListeners();
    _persist((prefs) => prefs.setStringList(
        _kFalHistory, _encodeFalHistory(_falHistory)));
  }

  /// به‌یاد سپردن آخرین شعر خوانده‌شده برای «ادامهٔ مطالعه»
  Future<void> saveLastPoemId(String poemId) async {
    if (_lastPoemId == poemId) return;
    _lastPoemId = poemId;
    notifyListeners();
    _persist((prefs) => prefs.setString(_kLastPoemId, poemId));
  }

  /// روشن/خاموش کردن حالت مطالعهٔ شبانه
  Future<void> setNightMode(bool value) async {
    if (_nightMode == value) return;
    _nightMode = value;
    notifyListeners();
    _persist((prefs) => prefs.setBool(_kNightMode, value));
  }

  /// ساخت متن کامل نسخهٔ پشتیبان (دلخواه‌ها + یادداشت‌ها + دفترچهٔ فال)
  String exportBackup() {
    return jsonEncode({
      'app': 'divan-fal-hafez',
      'v': 1,
      'favorites': _favorites.toList(),
      'notes': _notes,
      'falHistory': _falHistory.map((e) => e.toJson()).toList(),
    });
  }

  /// بازیابی از متن کپی‌شدهٔ نسخهٔ پشتیبان؛ در صورت نامعتبر بودن
  /// فرمت، false برمی‌گرداند و هیچ داده‌ای دست‌نخورده می‌ماند.
  bool importBackup(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return false;
      if (decoded['app'] != 'divan-fal-hafez') return false;

      final favorites = <String>{};
      final rawFavorites = decoded['favorites'];
      if (rawFavorites is List) {
        favorites.addAll(rawFavorites.whereType<String>());
      }

      final notes = <String, String>{};
      final rawNotes = decoded['notes'];
      if (rawNotes is Map) {
        rawNotes.forEach((key, value) {
          if (key is String && value is String) notes[key] = value;
        });
      }

      final history = <FalEntry>[];
      final rawHistory = decoded['falHistory'];
      if (rawHistory is List) {
        for (final item in rawHistory) {
          if (item is Map<String, dynamic>) {
            try {
              history.add(FalEntry.fromJson(item));
            } catch (_) {
              // یک ورودی خراب کل بازیابی را از کار نمی‌اندازد
            }
          }
        }
      }

      _favorites = favorites;
      _notes = notes;
      _falHistory = history.take(maxFalHistory).toList();
      notifyListeners();
      _persist((prefs) => prefs.setStringList(
          _kFavorites, _favorites.toList()));
      _persist((prefs) => prefs.setStringList(
          _kNotes, _encodeNoteMap(_notes)));
      _persist((prefs) => prefs.setStringList(
          _kFalHistory, _encodeFalHistory(_falHistory)));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ————— ابزارهای سریال‌سازی —————

  static Map<String, String> _decodeNoteList(List<String>? raw) {
    final notes = <String, String>{};
    if (raw == null) return notes;
    for (final entry in raw) {
      final sep = entry.indexOf('␞');
      if (sep > 0) notes[entry.substring(0, sep)] = entry.substring(sep + 1);
    }
    return notes;
  }

  static List<String> _encodeNoteMap(Map<String, String> notes) =>
      notes.entries.map((e) => '${e.key}␞${e.value}').toList();

  static List<FalEntry> _decodeFalHistory(List<String>? raw) {
    final entries = <FalEntry>[];
    if (raw == null) return entries;
    for (final line in raw) {
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          entries.add(FalEntry.fromJson(decoded));
        }
      } catch (_) {
        // ورودی خراب نادیده گرفته می‌شود
      }
    }
    return entries;
  }

  static List<String> _encodeFalHistory(List<FalEntry> entries) =>
      entries.map((e) => jsonEncode(e.toJson())).toList();
}
