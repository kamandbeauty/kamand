import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

/// مدل یک فال حافظ (یک غزل از دیوان + تعبیر فال)
class HafezFal {
  const HafezFal({
    required this.number,
    required this.verses,
    required this.meaning,
  });

  /// شمارهٔ غزل در دیوان (۱ تا ۴۹۵)
  final int number;

  /// متن کامل غزل
  final String verses;

  /// تعبیر فال
  final String meaning;

  /// مصرع اول غزل - عنوان مرسوم هر غزل در دیوان
  String get firstMesra => verses.split('\n').first.trim();
}

/// مخزن آفلاین فال‌ها.
///
/// کل دیوان حافظ (۴۹۵ غزل به همراه تعبیر) در فایل
/// assets/data/hafez_fals.json داخل خود برنامه ذخیره شده است؛
/// یعنی گرفتن فال همیشه، حتی بدون اینترنت، ممکن است.
class FalRepository {
  FalRepository._();

  static const String _assetPath = 'assets/data/hafez_fals.json';

  /// کش داخلی تا فایل فقط یک‌بار خوانده شود
  static List<HafezFal>? _fals;

  static final Random _random = Random();

  static Future<List<HafezFal>> _loadAll() async {
    final cached = _fals;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_assetPath);
    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (e) => HafezFal(
            number: (e['n'] as num).toInt(),
            verses: e['v'] as String,
            meaning: e['m'] as String,
          ),
        )
        .toList(growable: false);

    if (list.isEmpty) {
      throw StateError('دیتای فال‌ها خالی است');
    }

    _fals = list;
    return list;
  }

  /// لیست کامل فال‌ها (به ترتیب شمارهٔ غزل)
  static Future<List<HafezFal>> all() async =>
      List.unmodifiable(await _loadAll());

  /// تعداد کل فال‌های موجود در برنامه
  static Future<int> count() async => (await _loadAll()).length;

  /// یک فال تصادفی - هر بار امکان آمدن هر کدام از ۴۹۵ غزل وجود دارد
  static Future<HafezFal> random() async {
    final fals = await _loadAll();
    return fals[_random.nextInt(fals.length)];
  }
}
