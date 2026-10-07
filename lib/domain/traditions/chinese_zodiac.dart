import '../../data/content/traditions_content.dart';

/// Chinese zodiac (Shengxiao) result for a birth date.
///
/// The animal/element/polarity derive from the Chinese lunar year of the
/// birth date; the year boundary is the (official, table-backed) Chinese
/// New Year, which falls between 21 Jan and 20 Feb.
class ChineseSign {
  const ChineseSign({
    required this.animalIndex,
    required this.elementIndex,
    required this.yang,
  });

  /// 0 = rat … 11 = pig.
  final int animalIndex;

  /// 0 = wood, 1 = fire, 2 = earth, 3 = metal, 4 = water.
  final int elementIndex;

  final bool yang;

  Map<String, Object?> get animal => TraditionsContent.chineseAnimals[animalIndex];
  Map<String, Object?> get element =>
      TraditionsContent.chineseElements[elementIndex];
}

/// Pure calculator for the Chinese tradition (no Flutter dependencies).
class ChineseZodiacCalculator {
  ChineseZodiacCalculator._();

  static int _mod(int v, int m) => ((v % m) + m) % m;

  /// The Chinese lunar year that contains [g] (Gregorian, any timezone —
  /// only the civil date matters).
  static int lunarYearFor(DateTime g) {
    var year = g.year;
    final md = _newYearFor(year);
    if (md != null) {
      final month = int.parse(md.substring(0, 2));
      final day = int.parse(md.substring(3, 5));
      final beforeCny = g.month < month || (g.month == month && g.day < day);
      if (beforeCny) year -= 1;
    }
    return year;
  }

  static String? _newYearFor(int year) {
    final i = year - TraditionsContent.chineseNewYearStartYear;
    if (i < 0 || i >= TraditionsContent.chineseNewYearDates.length) return null;
    return TraditionsContent.chineseNewYearDates[i];
  }

  /// Chinese New Year (Gregorian month/day) of the given year, or null when
  /// outside the embedded 1900–2100 table.
  static String? newYearOf(int year) => _newYearFor(year);

  static ChineseSign signFor(DateTime g) {
    final y = lunarYearFor(g);
    final animal = _mod(y - 4, 12);
    final stem = _mod(y - 4, 10);
    return ChineseSign(
      animalIndex: animal,
      elementIndex: stem ~/ 2,
      yang: stem % 2 == 0,
    );
  }

  /// Relationship level between two animals (by index): 'high', 'medium'
  /// or 'low' — based on the classic San He triads, Liu He pairs and Chong
  /// (clash) pairs.
  static String compatibility(int a, int b) {
    final sanHe = TraditionsContent.chineseRules['sanHe']! as List<List<int>>;
    final liuHe = TraditionsContent.chineseRules['liuHe']! as List<List<int>>;
    final chong = TraditionsContent.chineseRules['chong']! as List<List<int>>;

    if (sanHe.any((g) => g.contains(a) && g.contains(b))) return 'high';
    if (liuHe.any((p) => p.contains(a) && p.contains(b))) return 'high';
    if (chong.any((p) => p.contains(a) && p.contains(b))) return 'low';
    return 'medium';
  }
}
