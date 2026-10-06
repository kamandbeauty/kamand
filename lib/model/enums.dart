/// شمارش‌های مشترک رابط کاربری و هوش مصنوعی.
library;

/// سطح حرفه‌ای بودن حریف‌ها.
enum Difficulty { easy, normal, hard, master }

extension DifficultyInfo on Difficulty {
  String get fa {
    switch (this) {
      case Difficulty.easy:
        return 'مبتدی';
      case Difficulty.normal:
        return 'متوسط';
      case Difficulty.hard:
        return 'حرفه‌ای';
      case Difficulty.master:
        return 'استاد';
    }
  }

  String get description {
    switch (this) {
      case Difficulty.easy:
        return 'محتاط می‌خواند و گاهی اشتباه بازی می‌کند.';
      case Difficulty.normal:
        return 'منطقی بازی می‌کند ولی کارت‌ها را کامل نمی‌شمارد.';
      case Difficulty.hard:
        return 'کارت‌ها را می‌شمارد، با یارش هماهنگ است و امتیاز جمع می‌کند.';
      case Difficulty.master:
        return 'بی‌رحم؛ حراجِ تهاجمی، شمارش کامل و بازیِ بهینه.';
    }
  }

  /// ضریب ریسک در مرحلهٔ خواندن.
  double get bidFactor {
    switch (this) {
      case Difficulty.easy:
        return 0.86;
      case Difficulty.normal:
        return 0.94;
      case Difficulty.hard:
        return 1.0;
      case Difficulty.master:
        return 1.05;
    }
  }

  /// احتمال بازیِ تصادفی (اشتباه انسانی).
  double get noise {
    switch (this) {
      case Difficulty.easy:
        return 0.35;
      case Difficulty.normal:
        return 0.12;
      case Difficulty.hard:
        return 0.0;
      case Difficulty.master:
        return 0.0;
    }
  }

  /// آیا کارت‌های بازی‌شده را به خاطر می‌سپارد؟
  bool get countsCards =>
      this == Difficulty.hard || this == Difficulty.master;
}

/// سرعت انیمیشن و نوبت ربات‌ها.
enum GameSpeed { slow, normal, fast }

extension GameSpeedInfo on GameSpeed {
  String get fa {
    switch (this) {
      case GameSpeed.slow:
        return 'آهسته';
      case GameSpeed.normal:
        return 'معمولی';
      case GameSpeed.fast:
        return 'سریع';
    }
  }

  Duration get botDelay {
    switch (this) {
      case GameSpeed.slow:
        return const Duration(milliseconds: 1200);
      case GameSpeed.normal:
        return const Duration(milliseconds: 700);
      case GameSpeed.fast:
        return const Duration(milliseconds: 330);
    }
  }
}

/// تمِ زمین بازی.
enum TableSurface {
  carpetRed,
  carpetBlue,
  carpetCream,
  carpetGreen,
  woodTable,
  parquet,
  greenFelt,
}

extension TableSurfaceInfo on TableSurface {
  String get fa {
    switch (this) {
      case TableSurface.carpetRed:
        return 'قالی گل‌سرخ';
      case TableSurface.carpetBlue:
        return 'قالی کاشان';
      case TableSurface.carpetCream:
        return 'قالی تبریز';
      case TableSurface.carpetGreen:
        return 'گلیم سبز';
      case TableSurface.woodTable:
        return 'میز چوبی قدیمی';
      case TableSurface.parquet:
        return 'پارکت';
      case TableSurface.greenFelt:
        return 'میز ماهوتی';
    }
  }

  /// مسیر تصویر؛ برای تمِ بدون تصویر، null.
  String? get asset {
    switch (this) {
      case TableSurface.carpetRed:
        return 'assets/images/surfaces/carpet-red.jpg';
      case TableSurface.carpetBlue:
        return 'assets/images/surfaces/carpet-blue.jpg';
      case TableSurface.carpetCream:
        return 'assets/images/surfaces/carpet-cream.jpg';
      case TableSurface.carpetGreen:
        return 'assets/images/surfaces/carpet-green.jpg';
      case TableSurface.woodTable:
        return 'assets/images/surfaces/wood-table.jpg';
      case TableSurface.parquet:
        return 'assets/images/surfaces/parquet.jpg';
      case TableSurface.greenFelt:
        return null;
    }
  }
}

/// طرح پشت کارت.
enum CardBack { crimson, navy, emerald, midnight, gold }

extension CardBackInfo on CardBack {
  String get fa {
    switch (this) {
      case CardBack.crimson:
        return 'لاکی';
      case CardBack.navy:
        return 'سرمه‌ای';
      case CardBack.emerald:
        return 'زمردی';
      case CardBack.midnight:
        return 'شبانه';
      case CardBack.gold:
        return 'طلایی';
    }
  }
}
