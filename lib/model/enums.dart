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

/// تمِ زمین بازی (محیطِ بازی).
enum TableSurface {
  teahouse,
  woodTable,
  carpetAntique,
  carpetSilk,
  carpetBoteh,
  carpetMiniature,
  parquet,
  greenFelt,
}

extension TableSurfaceInfo on TableSurface {
  String get fa {
    switch (this) {
      case TableSurface.teahouse:
        return 'چای‌خانه';
      case TableSurface.woodTable:
        return 'میز چوبی';
      case TableSurface.carpetAntique:
        return 'قالی قدیمی';
      case TableSurface.carpetSilk:
        return 'قالی ابریشم';
      case TableSurface.carpetBoteh:
        return 'قالی بته‌جقه';
      case TableSurface.carpetMiniature:
        return 'قالی مینیاتور';
      case TableSurface.parquet:
        return 'پارکت';
      case TableSurface.greenFelt:
        return 'میز ماهوتی';
    }
  }

  /// توضیحِ کوتاه برای صفحهٔ تنظیمات.
  String get faHint {
    switch (this) {
      case TableSurface.teahouse:
        return 'تختِ چوبیِ قهوه‌خانه با قالیچه و استکان کمرباریک';
      case TableSurface.woodTable:
        return 'میزِ چوبیِ کهنه و صیقلی';
      case TableSurface.carpetAntique:
        return 'قالیِ دست‌بافِ رنگ‌ورورفته';
      case TableSurface.carpetSilk:
        return 'قالیِ ابریشمِ قم، سبز و طلایی';
      case TableSurface.carpetBoteh:
        return 'نقشِ سراسریِ بته‌جقه';
      case TableSurface.carpetMiniature:
        return 'قالیِ تابلویی با نگارهٔ مینیاتور';
      case TableSurface.parquet:
        return 'کفِ پارکتِ روشن';
      case TableSurface.greenFelt:
        return 'ماهوتِ سادهٔ سبز، بدون تصویر';
    }
  }

  /// مسیر تصویر؛ برای تمِ بدون تصویر، null.
  String? get asset {
    switch (this) {
      case TableSurface.teahouse:
        return 'assets/images/surfaces/teahouse.jpg';
      case TableSurface.woodTable:
        return 'assets/images/surfaces/wood-table.jpg';
      case TableSurface.carpetAntique:
        return 'assets/images/surfaces/carpet-antique.jpg';
      case TableSurface.carpetSilk:
        return 'assets/images/surfaces/carpet-silk.jpg';
      case TableSurface.carpetBoteh:
        return 'assets/images/surfaces/carpet-boteh.jpg';
      case TableSurface.carpetMiniature:
        return 'assets/images/surfaces/carpet-miniature.jpg';
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
