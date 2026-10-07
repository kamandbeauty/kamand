import '../../data/content/traditions_content.dart';

/// Pythagorean numerology + Persian Abjad (pure calculator).
///
/// Life path uses the three-cycle reduction (month / day / year reduced
/// separately, master numbers 11-22-33 preserved) — the standard
/// Pythagorean method. Abjad values follow the classical Arabic-Persian
/// letter-value table (ابجد، هوّز، حطّی، کلمن…).
class NumerologyCalculator {
  NumerologyCalculator._();

  static const List<int> _masterNumbers = [11, 22, 33];

  static int _digitSum(int n) {
    var v = n;
    var sum = 0;
    while (v > 0) {
      sum += v % 10;
      v ~/= 10;
    }
    return sum;
  }

  /// Reduce to a single digit, preserving the master numbers 11/22/33
  /// (both as input values and as intermediate digit sums).
  static int reduce(int n) {
    if (n <= 0) return 0;
    if (_masterNumbers.contains(n)) return n;
    final s = _digitSum(n);
    if (s < 10 || _masterNumbers.contains(s)) return s;
    return reduce(s);
  }

  /// Life-path number from the (Gregorian) birth date.
  static int lifePath(DateTime g) =>
      reduce(reduce(g.month) + reduce(g.day) + reduce(g.year));

  /// Personal-year number for the current Gregorian year.
  static int personalYear(DateTime birth, int currentYear) => reduce(
        reduce(birth.month) + reduce(birth.day) + reduce(currentYear),
      );

  /// Raw Abjad value of a Persian/Arabic name (0 when empty/unsupported).
  static int abjadValue(String name) {
    var sum = 0;
    for (final rune in name.runes) {
      final ch = String.fromCharCode(rune);
      sum += TraditionsContent.abjadValues[ch] ?? 0;
    }
    return sum;
  }

  /// Abjad value reduced to its interpretive number (masters preserved).
  static int abjadReduced(int value) => reduce(value);
}
