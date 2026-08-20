/// خال‌های کارت در بازی حکم.
///
/// این enum مستقل از UI است؛ نام فارسی فقط برای نمایش از طریق
/// [faName] در دسترس قرار گرفته تا لایهٔ UI مجبور به Hardcode نباشد.
enum Suit {
  hearts('دل', 'H'),
  diamonds('خشت', 'D'),
  spades('پیک', 'S'),
  clubs('گشنیز', 'C');

  const Suit(this.faName, this.code);

  /// نام فارسی خال (برای نمایش در UI).
  final String faName;

  /// کد تک‌حرفی برای سریالایز/دیباگ.
  final String code;

  static Suit fromCode(String code) => Suit.values.firstWhere(
        (s) => s.code == code,
        orElse: () => throw ArgumentError('Unknown suit code: $code'),
      );
}
