import 'dart:convert';
import 'dart:math';

import 'package:fale_hafez/data/poem.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// مخزن آفلاین آثار حافظ.
///
/// کل مجموعهٔ آثار (غزلیات، رباعیات، قطعات، قصاید، منتسبات و مثنویات)
/// در assets/data/hafez_divan.json داخل خود برنامه ذخیره شده است.
/// ترکیب دقیق فعلی دیتاست (سنپ‌شات: ۵۹۵ اثر) صرفاً یک مشخصهٔ داده‌ای
/// است و در منطق برنامه قاعدهٔ تجاری نیست — منطق برنامه روی فهرستِ
/// بارگیری‌شده کار می‌کند، نه روی عددهای ثابت.
class DivanRepository {
  DivanRepository._();

  static const String _assetPath = 'assets/data/hafez_divan.json';

  static List<Poem>? _poems;
  static final Map<PoemCategory, List<Poem>> _byCategory = {};
  static final Map<String, Poem> _byId = {};
  static final Random _random = Random();

  /// در پرواز: اگر دو خواسته هم‌زمان بیایند، فایل فقط یک‌بار خوانده و
  /// تجزیه می‌شود (قبلاً هر دو مسیر موازی پارس می‌کردند)
  static Future<void>? _loading;

  static Future<void> _ensureLoaded() {
    if (_poems != null) return Future<void>.value();
    return _loading ??= _loadOnce();
  }

  static Future<void> _loadOnce() async {
    try {
      await _parse();
    } finally {
      _loading = null;
    }
  }

  /// خواندن و اعتبارسنجی سخت‌گیرانهٔ دیتاست.
  ///
  /// هر خرابی در ساختار دیتاست — فیلد نامعتبر، شناسهٔ خالی یا
  /// تکراری، ابیاتِ خالی، شمارهٔ نامعتبر یا تکراری در یک بخش — با
  /// زمانی همراه است و FormatException پرتاب می‌کند تا دیتاستِ
  /// بی‌کیفیت (تهاجمی‌تر: در زمان CI، تست حاکیت دیتاست گیر کند) هرگز
  /// بی‌صدا با رفتار حدسی جبران شود.
  static Future<void> _parse() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException(
          'ساختار ریشهٔ hafez_divan.json باید فهرست (List) شعرها باشد');
    }

    final seenIds = <String>{};
    final seenNumbers = <({PoemCategory category, int number})>{};
    final list = <Poem>[];
    for (var i = 0; i < decoded.length; i++) {
      final poem = _parsePoem(decoded[i], i);
      if (!seenIds.add(poem.id)) {
        throw FormatException(
            'شناسهٔ تکراری در دیتاست دیوان: «${poem.id}»');
      }
      if (!seenNumbers.add((category: poem.category, number: poem.number))) {
        throw FormatException(
            'شمارهٔ تکراری ${poem.number} در بخش «${poem.category.name}»');
      }
      list.add(poem);
    }

    if (list.isEmpty) {
      throw StateError('دیتای دیوان خالی است');
    }

    for (final poem in list) {
      _byId[poem.id] = poem;
      _byCategory.putIfAbsent(poem.category, () => <Poem>[]).add(poem);
    }
    _poems = list;
  }

  static Poem _parsePoem(Object? entry, int index) {
    try {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('شعر باید نگاشتِ کلید‌دار (Map) باشد');
      }
      final poem = Poem(
        id: entry['id'] as String,
        category: PoemCategory.fromKey(entry['c'] as String),
        number: (entry['n'] as num).toInt(),
        verses: entry['v'] as String,
        meaning: entry['m'] as String?,
        title: entry['t'] as String?,
      );
      if (poem.id.isEmpty) {
        throw const FormatException('شناسهٔ شعر خالی است');
      }
      if (poem.verses.trim().isEmpty) {
        throw FormatException('ابیات شعر «${poem.id}» خالی است');
      }
      if (poem.number <= 0) {
        throw FormatException(
            'شمارهٔ نامعتبر (َغیرمثبت) برای شعر «${poem.id}»: ${poem.number}');
      }
      if (poem.title != null && poem.title!.isEmpty) {
        throw FormatException(
            'عنوان شعر «${poem.id}» رشتهٔ خالی است (باید null یا متن باشد)');
      }
      return poem;
    } on FormatException catch (e) {
      throw FormatException(
          'اعتبارسنجی شعر شمارهٔ ${index + 1} دیتاست دیوان ناموفق بود: ${e.message}');
    } on TypeError {
      throw FormatException(
          'خواندن شعر شمارهٔ ${index + 1} در دیتاست دیوان ناموفق بود: کلید یا نوع دادهٔ نامعتبراست');
    }
  }

  /// همهٔ اشعار (به ترتیب بخش‌ها)
  static Future<List<Poem>> all() async {
    await _ensureLoaded();
    return List.unmodifiable(_poems!);
  }

  /// شعرهای یک بخش مشخص
  static Future<List<Poem>> byCategory(PoemCategory category) async {
    await _ensureLoaded();
    return List.unmodifiable(_byCategory[category] ?? const <Poem>[]);
  }

  /// تعداد اشعار - در کل یا در یک بخش
  static Future<int> count([PoemCategory? category]) async {
    await _ensureLoaded();
    if (category == null) return _poems!.length;
    return _byCategory[category]?.length ?? 0;
  }

  /// یافتن شعر با شناسهٔ یکتا
  static Future<Poem> findById(String id) async {
    await _ensureLoaded();
    final poem = _byId[id];
    if (poem == null) {
      throw ArgumentError('شعری با شناسهٔ «$id» یافت نشد');
    }
    return poem;
  }

  /// یافتن گروهی شعرها بر اساس شناسه‌ها (مثلاً فهرست دلخواه‌ها).
  /// نگاشت مستقیم از کش انجام می‌شود — یک await کلی، نه یک await برای
  /// هر شناسه؛ ترتیب ورودی حفظ و شناسه‌های ناموجود نادیده گرفته می‌شوند.
  static Future<List<Poem>> findByIds(Iterable<String> ids) async {
    await _ensureLoaded();
    return ids
        .map((id) => _byId[id])
        .whereType<Poem>()
        .toList(growable: false);
  }

  /// انتخاب تصادفی یک شعر از فهرست داده‌شده.
  /// روی فهرستِ خالی StateError پرتاب می‌کند تا یک کالِ میان‌تیجب با
  /// ایندکس نامعتبر (crash خام) به جای خطای گفتنی اتفاق نیفتد.
  @visibleForTesting
  static Poem pickRandom(List<Poem> items) {
    if (items.isEmpty) {
      throw StateError(
          'فهرست انتخاب تصادفی خالی است؛ برنامه نمی‌تواند از مجموعهٔ تهی شعر برگرداند');
    }
    return items[_random.nextInt(items.length)];
  }

  /// یک غزل تصادفی - برای فال حافظ
  static Future<Poem> randomGhazal() async {
    final ghazals = await byCategory(PoemCategory.ghazal);
    return pickRandom(ghazals);
  }
}
