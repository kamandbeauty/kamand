import '../models/numerology_result.dart';

class NumerologyEngine {
  const NumerologyEngine();

  NumerologyResult fromAbjadTotal(int total) {
    final value = _reduce(total);
    return NumerologyResult(
      value: value,
      title: 'عدد سنتی نام: $value',
      description: 'تفسیر منبع‌دار این عدد هنوز در آرشیو محتوایی ثبت نشده است. در این نسخه فقط مقدار محاسبه‌شده نمایش داده می‌شود.',
      systemTitle: 'کاهش رقمی بر پایه مجموع ابجد؛ وضعیت محتوایی: unverified',
      disclaimer: 'این نتیجه سنتی و تفسیری است و پیش‌بینی علمی شخصیت یا آینده محسوب نمی‌شود.',
    );
  }

  int _reduce(int value) {
    if (value <= 9) return value;
    var current = value;
    while (current > 9) {
      current = current
          .toString()
          .split('')
          .map(int.parse)
          .reduce((a, b) => a + b);
    }
    return current;
  }
}
