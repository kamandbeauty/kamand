/// بخش‌های مختلف آثار حافظ در برنامه
enum PoemCategory {
  ghazal('غزلیات', 'غزل'),
  robaee('رباعیات', 'رباعی'),
  ghete('قطعات', 'قطعه'),
  ghaside('قصاید', 'قصیدهٔ'),
  montasab('اشعار منتسب', 'شعر منتسب'),
  masnavi('مثنویات', 'مثنوی');

  const PoemCategory(this.sectionTitle, this.singularTitle);

  /// نام بخش به صورت جمع - مثل «غزلیات»
  final String sectionTitle;

  /// نام مفرد برای نمایش شماره - مثل «غزل ۱۲»
  final String singularTitle;

  static PoemCategory fromKey(String key) => values.firstWhere(
        (c) => c.name == key,
        orElse: () => PoemCategory.ghazal,
      );
}

/// مدل یک اثر از دیوان حافظ (غزل، رباعی، قطعه، قصیده، منتسب یا مثنوی)
class Poem {
  const Poem({
    required this.id,
    required this.category,
    required this.number,
    required this.verses,
    this.meaning,
    this.title,
  });

  /// شناسهٔ یکتا - مثل ghazal-138
  final String id;

  /// بخش دیوان
  final PoemCategory category;

  /// شمارهٔ شعر در بخش خودش
  final int number;

  /// متن کامل شعر (هر بیت/مصرع در یک خط)
  final String verses;

  /// تعبیر فال (فقط برای غزلیات)
  final String? meaning;

  /// عنوان خاص (مثلاً «ساقی‌نامه» یا موضوع قصیده)؛ اگر نباشد
  /// از روی بخش و شماره ساخته می‌شود
  final String? title;

  /// مصرع اول شعر - عنوان مرسوم در دیوان
  String get firstMesra => verses.split('\n').first.trim();

  /// عنوان نمایشی - مثل «غزل ۱۲» یا «ساقی‌نامه»
  String get displayTitle => title ?? '${category.singularTitle} $number';
}
