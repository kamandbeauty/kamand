/// رتبه‌های کارت — از ۲ تا آس.
///
/// مقدار [value] برای مقایسهٔ بزرگی کارت استفاده می‌شود (آس = ۱۴).
enum Rank {
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K'),
  ace(14, 'A');

  const Rank(this.value, this.symbol);

  /// ارزش عددی برای مقایسه (۲ تا ۱۴).
  final int value;

  /// نماد لاتین روی کارت.
  final String symbol;

  static Rank fromSymbol(String symbol) => Rank.values.firstWhere(
        (r) => r.symbol == symbol,
        orElse: () => throw ArgumentError('Unknown rank symbol: $symbol'),
      );
}
