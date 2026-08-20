/// جایگاه چهار بازیکن دور میز.
///
/// ترتیب چرخش نوبت در حکم «به سمت راست» است؛ با چیدمان صفحهٔ عمودی
/// (بازیکن انسانی پایین صفحه و رو به مرکز) این یعنی روی تصویر:
/// پایین → چپ → بالا → راست. [next] همان ترتیب را پیاده‌سازی می‌کند.
enum Seat {
  south(0),
  west(1),
  north(2),
  east(3);

  const Seat(this.index);

  final int index;

  /// نفر بعدی در نوبت (چرخهٔ ثابت: south→west→north→east→south).
  Seat get next => Seat.values[(index + 1) % 4];

  /// نفر قبلی در نوبت.
  Seat get previous => Seat.values[(index + 3) % 4];

  /// آیا این دو جایگاه در یک تیم هستند؟ (روبه‌روی هم یارند)
  bool isPartnerOf(Seat other) => (index - other.index).abs() == 2;

  Seat get partner => Seat.values[(index + 2) % 4];

  /// تیم هر جایگاه: south/north تیم صفر، west/east تیم یک.
  int get teamIndex => index % 2;

  static Seat fromIndex(int index) => Seat.values[index % 4];
}

/// مرحله‌های چرخهٔ حیات یک مسابقه.
enum GamePhase {
  /// تعیین حاکم اولیه (پخش کارت تا ظاهر شدن اولین آس).
  hakimDetermination,

  /// پخش ۵ کارت اول و انتظار برای انتخاب حکم توسط حاکم.
  initialDeal,

  /// انتظار مشخص برای انتخاب خال حکم.
  awaitingTrumpSelection,

  /// پخش باقی کارت‌ها (۴+۴).
  dealing,

  /// بازی دست (۱۳ تریک).
  playing,

  /// پایان دست — محاسبهٔ امتیاز.
  roundEnd,

  /// پایان مسابقه — یک تیم به سقف امتیاز رسیده است.
  matchEnd,
}

/// سطح دشواری هوش مصنوعی.
enum AiDifficulty { easy, normal, hard }
