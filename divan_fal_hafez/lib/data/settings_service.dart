import 'dart:convert';

import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/poem.dart';
import 'package:fale_hafez/fonts.dart';
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
/// شخصی، دفترچهٔ فال و آخرین شعر خوانده‌شده.
/// همه به‌صورت آفلاین روی دستگاه ذخیره می‌شوند.
class SettingsService extends ChangeNotifier {
  static const String _kFont = 'poem_font_key';
  static const String _kScale = 'poem_font_scale';
  static const String _kFavorites = 'poem_favorites';
  static const String _kNotes = 'poem_notes';
  static const String _kFalHistory = 'fal_history';
  static const String _kLastPoemId = 'last_poem_id';

  /// کلید ذخیرهٔ افکت انتخابیِ اسکنِ اثر انگشت در صفحهٔ نیّت
  static const String _kFingerprintEffect = 'fingerprint_effect';

  /// افکت‌های قابل‌انتخاب برای زمانِ نگه‌داشتنِ اثر انگشت:
  /// 'ink' = پخش‌شدنِ قطرهٔ جوهر، 'petal' = پخش‌شدنِ گلبرگ‌ها
  static const List<String> fingerprintEffects = ['ink', 'petal'];

  /// افکت پیش‌فرض (جوهر) — حفظِ رفتارِ قدیمی برای کاربران موجود
  static const String defaultFingerprintEffect = 'ink';

  /// مهر نسخهٔ طرح (schema) داده‌های ذخیره‌شده روی دستگاه؛ برای
  /// مهاجرت‌های آیندهٔ ساختار ذخیره‌سازی استفاده می‌شود.
  static const String _kSchemaVersion = 'prefs_schema_version';

  /// نسخهٔ فعلی طرح ذخیره‌سازی
  static const int currentSchemaVersion = 1;

  /// کمترین و بیشترین ضریب بزرگنمایی قلم اشعار
  static const double minScale = 0.7;
  static const double maxScale = 2.0;
  static const double defaultScale = 1.0;

  /// سقف نگه‌داری ورودی‌های دفترچهٔ فال
  static const int maxFalHistory = 100;

  /// نسخهٔ فعلی ساختار نسخهٔ پشتیبان:
  /// - نسخهٔ ۱: فقط اطلاعات شخصی (دلخواه‌ها، یادداشت‌ها، دفترچهٔ فال)
  /// - نسخهٔ ۲: + ترجیحات (قلم، اندازهٔ قلم) و آخرین شعر خوانده‌شده
  static const int currentBackupVersion = 2;

  SharedPreferences? _prefs;

  String _fontKey = defaultPoemFontKey;
  double _poemScale = defaultScale;
  Set<String> _favorites = {};
  Map<String, String> _notes = {};
  List<FalEntry> _falHistory = [];
  String? _lastPoemId;
  String _fingerprintEffect = defaultFingerprintEffect;

  String get fontKey => _fontKey;
  double get poemScale => _poemScale;
  Set<String> get favorites => Set.unmodifiable(_favorites);
  List<FalEntry> get falHistory => List.unmodifiable(_falHistory);
  String? get lastPoemId => _lastPoemId;
  String get fingerprintEffect => _fingerprintEffect;

  /// خواندن تنظیمات ذخیره‌شده از حافظهٔ دستگاه.
  ///
  /// همهٔ مقادیر هنگام خواندن اعتبارسنجی می‌شوند: قلمِ نامعتبر به
  /// قلم پیش‌فرض، ضریبِ خارج از بازه به مرز مجاز، و NaN/Inf به مقدار
  /// پیش‌فرض بازمی‌گردد. دیتای خراب روی دستگاه هرگز وضعیت نامعتبر
  /// به حافظهٔ برنامه تزریق نمی‌کند.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _migratePrefsIfNeeded();

    final rawFont = _prefs!.getString(_kFont);
    _fontKey = poemFontFamilies.containsKey(rawFont)
        ? rawFont!
        : defaultPoemFontKey;
    _poemScale = _sanitizeScale(_prefs!.getDouble(_kScale));
    _favorites = (_prefs!.getStringList(_kFavorites) ?? const <String>[])
        .where((id) => id.isNotEmpty)
        .toSet();
    _notes = _decodeNoteList(_prefs!.getStringList(_kNotes));
    _falHistory = _decodeFalHistory(_prefs!.getStringList(_kFalHistory))
        .take(maxFalHistory)
        .toList();
    final rawLast = _prefs!.getString(_kLastPoemId);
    _lastPoemId = (rawLast == null || rawLast.isEmpty) ? null : rawLast;
    final rawEffect = _prefs!.getString(_kFingerprintEffect);
    _fingerprintEffect = fingerprintEffects.contains(rawEffect)
        ? rawEffect!
        : defaultFingerprintEffect;
    notifyListeners();
  }

  /// مهاجرت طرح داده‌های ذخیره‌شده — حاضر برای مهاجرت‌های آینده.
  ///
  /// هر مهاجرت آینده به‌عنوان یک case جدید اضافه می‌شود و مراحل به
  /// ترتیب پشت‌سر‌هم اجرا می‌شوند؛ در پایان مهر نسخهٔ فعلی ثبت می‌شود.
  void _migratePrefsIfNeeded() {
    final int fromVersion =
        _prefs!.getInt(_kSchemaVersion) ?? 0; // 0 = قبل از مهر نسخه
    if (fromVersion >= currentSchemaVersion) {
      if (fromVersion > currentSchemaVersion) {
        debugPrint('SettingsService: مهر طرح از نسخهٔ جدیدتری است '
            '($fromVersion)؛ دست‌زی نمی‌شود');
      }
      return;
    }
    switch (fromVersion) {
      case 0:
        // مهاجرت از طرح اولیه: ساختار کلیدها سازگار است؛ فقط مهر می‌خورد.
        // نکتهٔ آینده: اگر نسخهٔ تازه‌ای کلیدی را تغییر دهد، این‌جا
        // به‌ترتیب case 1، case 2 و… ادامه پیدا می‌کند.
        break;
    }
    // مهر نسخهٔ فعلی با همان صف سریالیِ نوشتن ثبت می‌شود تا با
    // نوشت‌های دیگر هم‌زمان نشود.
    _persist((prefs) => prefs.setInt(_kSchemaVersion, currentSchemaVersion));
  }

  bool isFavorite(String poemId) => _favorites.contains(poemId);

  String? noteFor(String poemId) => _notes[poemId];

  bool get notesEmpty => _notes.isEmpty;

  // ————— صف سریالیِ نوشتن روی حافظهٔ دستگاه —————

  /// زنجیرهٔ ترتیبیِ نوشت‌ها؛ هر عملیات پس از پایان موفق یا ناموفق
  /// عملیات قبلی اجرا می‌شود تا ترتیبِ نهاییِ ذخیره‌شده همیشه برابر
  /// آخرین تغییرِ کاربر باشد (نوشت‌های موازیِ پرسرعت همدیگر را
  /// بازنویسی نمی‌کنند).
  Future<void> _writeChain = Future<void>.value();

  /// فقط برای تست: تکمیل شدن تمام نوشت‌های صف‌بندی‌شده تاکنون.
  @visibleForTesting
  Future<void> debugWritesIdle() => _writeChain;

  /// نوشتن روی حافظهٔ دستگاه با تحمل خطا و ترتیب تضمین‌شده.
  ///
  /// اگر ذخیره‌سازی شکست بخورد (کمبود فضا یا خطای I/O)، وضعیتِ درونِ
  /// حافظهٔ برنامه معتبر می‌ماند و خطا بازگردانده نمی‌شود تا به UI
  /// به‌عنوان استثنا نشیرجهد (که در GetX سادِ برنامه‌ی ما بی‌معناست؛
  /// کاربر همان وضعیتِ معتبر در حافظه را می‌بیند) ولی بی‌سروصدا هم از
  /// دست نمی‌رود: در لاگ دیباگ ثبت می‌شود.
  void _persist(Future<bool> Function(SharedPreferences prefs) write) {
    final prefs = _prefs;
    if (prefs == null) return;
    _writeChain = _writeChain
        .then((_) => write(prefs))
        .onError((Object error, StackTrace _) {
      debugPrint('SettingsService: خطا در ذخیره‌سازی تنظیمات — $error');
      return false;
    }).then((ok) {
      if (ok == false) {
        debugPrint(
            'SettingsService: ذخیرهٔ تنظیمات ناموفق بود (برگشت false)');
      }
    });
  }

  static double _sanitizeScale(num? raw,
          {double fallback = defaultScale}) =>
      (raw == null || raw.isNaN || raw.isInfinite)
          ? fallback
          : raw.clamp(minScale, maxScale).toDouble();

  Future<void> setFont(String key) async {
    if (_fontKey == key || !poemFontFamilies.containsKey(key)) return;
    _fontKey = key;
    notifyListeners();
    _persist((prefs) => prefs.setString(_kFont, key));
  }

  Future<void> setPoemScale(double scale) async {
    final clamped = _sanitizeScale(scale);
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
    _persist(
        (prefs) => prefs.setStringList(_kNotes, _encodeNoteMap(_notes)));
  }

  /// ثبت فال تازه در «دفترچهٔ فال» (تازه‌ترین در ابتدای فهرست).
  ///
  /// **سیاست تکرار (مستند):** اگر همان شعر بلافاصله دوباره فال شود
  /// (دو فال پیاپیِ یکسانِ متوالی)، ورودیِ اول به‌روزرسانی می‌شود و
  /// ردیفِ دوم ساخته نمی‌شود تا دفترچهٔ فال با دوباره‌زدنِ زمانی از
  /// همان شعر شلوغ نشود؛ تکرار شعر پس از یک فالِ دیگر (تکرارِ
  /// غیرمتوالی) ردیفِ مستقل می‌سازد چون از نظر تاریخچه دو رویدادِ
  /// واقعی مجزا است.
  Future<void> recordFal(Poem poem) async {
    final now = DateTime.now();
    if (_falHistory.isNotEmpty && _falHistory.first.poemId == poem.id) {
      // فالِ همان شعرِ بلافاصله قبلی؛ فقط زمان به‌روزرسانی می‌شود.
      _falHistory[0] = FalEntry(
          poemId: poem.id, number: poem.number, occurredAt: now);
    } else {
      _falHistory.insert(
        0,
        FalEntry(poemId: poem.id, number: poem.number, occurredAt: now),
      );
    }
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

  /// انتخاب افکتِ اسکنِ اثر انگشت (جوهر یا گلبرگ)
  Future<void> setFingerprintEffect(String key) async {
    if (_fingerprintEffect == key || !fingerprintEffects.contains(key)) {
      return;
    }
    _fingerprintEffect = key;
    notifyListeners();
    _persist((prefs) => prefs.setString(_kFingerprintEffect, key));
  }

  // ————— پشتیبان‌گیری —————

  /// ساخت متن کامل نسخهٔ پشتیبان: دلخواه‌ها + یادداشت‌ها + دفترچهٔ فال
  /// + ترجیحات (قلم و اندازهٔ قلم) + آخرین شعر خوانده‌شده
  /// (نسخهٔ ۲ — پشتیبانِ کامل; دادهٔ کاربر در انتقال از دست نمی‌رود).
  String exportBackup() {
    return jsonEncode({
      'app': 'divan-fal-hafez',
      'v': currentBackupVersion,
      'favorites': _favorites.toList(),
      'notes': _notes,
      'falHistory': _falHistory.map((e) => e.toJson()).toList(),
      'font': _fontKey,
      'poemScale': _poemScale,
      'lastPoemId': _lastPoemId,
      'fingerprintEffect': _fingerprintEffect,
    });
  }

  /// بازیابی از متن کپی‌شدهٔ نسخهٔ پشتیبان؛ در صورت نامعتبر بودن
  /// فرمت، false برمی‌گرداند و هیچ داده‌ای دست‌نخورده می‌ماند.
  ///
  /// پردازش اتمیک است: ابتدا تجزیه و اعتبارسنجی‌ی کامل انجام می‌شود و
  /// فقط در صورت سلامت، همهٔ تغییرات یک‌جا commit (اعمال و ذخیره)
  /// می‌شوند. شناسه‌های جعلی (فاقد شعر در دیتاست) حذف می‌شوند تا
  /// لیست‌های دلخواه/یادداشت/دفترچه به شعرهای خیالی ارجاع ندهند.
  Future<bool> importBackup(String text) async {
    final Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(text);
      if (parsed is! Map<String, dynamic>) return false;
      if (parsed['app'] != 'divan-fal-hafez') return false;
      decoded = parsed;
    } catch (_) {
      return false;
    }

    // نسخه‌بندیِ ساختار نسخهٔ پشتیبان: نسخهٔ نامشخص رد می‌شود تا
    // unknown handling از نیما سازگاری به دردسر تبدیل نشود.
    final version = decoded['v'];
    if (version is! int) return false;
    switch (version) {
      case 1:
        // پشتیبانِ قدیمی: فقط اطلاعات شخصی؛ ترجیحات همان پیش‌فرض باقی می‌ماند.
        break;
      case 2:
        // کامل: شامل ترجیحات و آخرین شعر.
        break;
      default:
        debugPrint('SettingsService: نسخهٔ پشتیبانِ ناشناخته ($version)');
        return false;
    }

    // ——— اعتبارسنجی مرکزی: کامل قبل از اعمال (commit) ———
    // هر استثنای غیرمنتظره در پاک‌سازی هم به ردِ کاملِ نسخه منجر می‌شود؛
    // بازیابیِ خراب هرگز وضعیتِ نیمه‌کارهٔ جزئی روی دستگاه برنمی‌دارد.
    final _SanitizedBackup? sanitized;
    try {
      sanitized = await _sanitizeBackup(decoded, version);
    } catch (e) {
      debugPrint('SettingsService: پاک‌سازی نسخهٔ پشتیبان ناموفق بود — $e');
      return false;
    }
    if (sanitized == null) return false;

    // ——— commit اتمیک: اعمال+ذخیره بعد از اعتبارسنجی کامل ———
    _favorites = sanitized.favorites;
    _notes = sanitized.notes;
    _falHistory = sanitized.falHistory;
    _fontKey = sanitized.fontKey;
    _poemScale = sanitized.poemScale;
    _lastPoemId = sanitized.lastPoemId;
    _fingerprintEffect = sanitized.fingerprintEffect;
    notifyListeners();
    _persist((prefs) => prefs.setStringList(
        _kFavorites, _favorites.toList()));
    _persist((prefs) => prefs.setStringList(
        _kNotes, _encodeNoteMap(_notes)));
    _persist((prefs) => prefs.setStringList(
        _kFalHistory, _encodeFalHistory(_falHistory)));
    _persist((prefs) => prefs.setString(_kFont, _fontKey));
    _persist((prefs) => prefs.setDouble(_kScale, _poemScale));
    _persist((prefs) =>
        prefs.setString(_kFingerprintEffect, _fingerprintEffect));
    if (_lastPoemId != null) {
      _persist((prefs) => prefs.setString(_kLastPoemId, _lastPoemId!));
    } else {
      _persist((prefs) => prefs.remove(_kLastPoemId));
    }
    return true;
  }

  /// پاک‌سازی مرکزیِ نسخهٔ پشتیبان در برابر دیتاست واقعی.
  ///
  /// اگر هر بخشی از پاک‌سازی شکست بخورد (مثلاً بارگیری دیوان) null
  /// برمی‌گردد و importBackup بدون هیچ تغییری رد می‌کند؛ وگر شیءِ
  /// پاک‌سازی‌شده به importBackup برای commitِ اتمیک برمی‌گردد.
  Future<_SanitizedBackup?> _sanitizeBackup(
      Map<String, dynamic> decoded, int version) async {
    // مجموعهٔ شناسه‌های واقعی دیوان برای حذف ارجاع‌های جعلی
    final Map<String, Poem> validPoems;
    try {
      validPoems = {for (final poem in await DivanRepository.all()) poem.id: poem};
    } catch (e) {
      debugPrint('SettingsService: دیوان برای اعتبارسنجی پشتیبان بارگیری نشد — $e');
      return null;
    }

    final favorites = <String>{};
    final rawFavorites = decoded['favorites'];
    if (rawFavorites is List) {
      for (final id in rawFavorites.whereType<String>()) {
        if (validPoems.containsKey(id)) favorites.add(id);
      }
    }

    final notes = <String, String>{};
    final rawNotes = decoded['notes'];
    if (rawNotes is Map) {
      rawNotes.forEach((key, value) {
        if (key is String &&
            value is String &&
            validPoems.containsKey(key)) {
          notes[key] = value;
        }
      });
    }

    final history = <FalEntry>[];
    final rawHistory = decoded['falHistory'];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is! Map<String, dynamic>) continue;
        FalEntry? entry;
        try {
          entry = FalEntry.fromJson(item);
        } catch (_) {
          entry = null; // ورودی خراب
        }
        if (entry == null) continue;
        final poem = validPoems[entry.poemId];
        // شعر باید وجود داشته باشد و شماره با دیتاستِ واقعی سازگار باشد
        if (poem == null || poem.number != entry.number) continue;
        history.add(entry);
      }
    }

    // فقط نسخهٔ ۲ ترجیحات را بازیابی می‌کند؛ در پشتیبانِ قدیمیِ نسخهٔ
    // ۱ این فیلدها وجود نداشتند، پس ترجیحاتِ *فعلیِ* کاربر حفظ می‌شود
    // (بازیابی دادهٔ قدیمی، انتخابِ کنونیِ قلم را از بین نمی‌برد).
    final String fontKey;
    final double poemScale;
    final String? lastPoemId;
    final String fingerprintEffect;
    if (version >= 2) {
      fontKey = poemFontFamilies.containsKey(decoded['font'])
          ? decoded['font'] as String
          : defaultPoemFontKey;
      poemScale =
          _sanitizeScale(decoded['poemScale'] as num?);
      final rawLast = decoded['lastPoemId'];
      lastPoemId =
          (rawLast is String && validPoems.containsKey(rawLast))
              ? rawLast
              : null;
      fingerprintEffect =
          fingerprintEffects.contains(decoded['fingerprintEffect'])
              ? decoded['fingerprintEffect'] as String
              : defaultFingerprintEffect;
    } else {
      fontKey = _fontKey;
      poemScale = _poemScale;
      lastPoemId = _lastPoemId;
      fingerprintEffect = _fingerprintEffect;
    }

    return _SanitizedBackup(
      favorites: favorites,
      notes: notes,
      falHistory: history.take(maxFalHistory).toList(),
      fontKey: fontKey,
      poemScale: poemScale,
      lastPoemId: lastPoemId,
      fingerprintEffect: fingerprintEffect,
    );
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

/// حمل‌کنندهٔ دادهٔ پاک‌سازی‌شدهٔ یک نسخهٔ پشتیبان؛ فقط به خودِ
/// importBackup برمی‌گردد (commitِ اتمیک همان‌جا انجام می‌شود).
class _SanitizedBackup {
  const _SanitizedBackup({
    required this.favorites,
    required this.notes,
    required this.falHistory,
    required this.fontKey,
    required this.poemScale,
    required this.lastPoemId,
    required this.fingerprintEffect,
  });

  final Set<String> favorites;
  final Map<String, String> notes;
  final List<FalEntry> falHistory;
  final String fontKey;
  final double poemScale;
  final String? lastPoemId;
  final String fingerprintEffect;
}
