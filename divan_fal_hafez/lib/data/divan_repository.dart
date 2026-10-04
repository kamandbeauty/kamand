import 'dart:convert';
import 'dart:math';

import 'package:fale_hafez/data/poem.dart';
import 'package:flutter/services.dart' show rootBundle;

/// مخزن آفلاین آثار حافظ.
///
/// کل مجموعه (۵۹۵ اثر: ۴۹۵ غزل، ۴۲ رباعی، ۳۴ قطعه، ۳ قصیده،
/// ۱۹ شعر منتسب و ۲ مثنوی) در assets/data/hafez_divan.json
/// داخل خود برنامه ذخیره شده است.
class DivanRepository {
  DivanRepository._();

  static const String _assetPath = 'assets/data/hafez_divan.json';

  static List<Poem>? _poems;
  static final Map<PoemCategory, List<Poem>> _byCategory = {};
  static final Map<String, Poem> _byId = {};
  static final Random _random = Random();

  static Future<void> _ensureLoaded() async {
    if (_poems != null) return;

    final raw = await rootBundle.loadString(_assetPath);
    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (e) => Poem(
            id: e['id'] as String,
            category: PoemCategory.fromKey(e['c'] as String),
            number: (e['n'] as num).toInt(),
            verses: e['v'] as String,
            meaning: e['m'] as String?,
            title: e['t'] as String?,
          ),
        )
        .toList(growable: false);

    if (list.isEmpty) {
      throw StateError('دیتای دیوان خالی است');
    }

    for (final poem in list) {
      _byId[poem.id] = poem;
      _byCategory.putIfAbsent(poem.category, () => <Poem>[]).add(poem);
    }
    _poems = list;
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

  /// یک غزل تصادفی - برای فال حافظ
  static Future<Poem> randomGhazal() async {
    final ghazals = await byCategory(PoemCategory.ghazal);
    return ghazals[_random.nextInt(ghazals.length)];
  }
}
