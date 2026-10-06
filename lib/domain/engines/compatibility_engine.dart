import '../../core/normalization/persian_normalizer.dart';
import '../models/compatibility_result.dart';

class CompatibilityEngine {
  const CompatibilityEngine();

  CompatibilityResult compareWrittenForm(String first, String second) {
    final a = PersianNormalizer.normalizeForSearch(first).replaceAll(' ', '');
    final b = PersianNormalizer.normalizeForSearch(second).replaceAll(' ', '');
    if (a.isEmpty || b.isEmpty) {
      return const CompatibilityResult(
        score: null,
        label: 'برای مقایسه دو نام کافی نیست',
        method: 'هر دو ورودی باید دارای حداقل یک حرف باشند.',
        disclaimer: 'این ابزار تحلیل رابطه یا پیش‌بینی شخصیت نیست.',
      );
    }

    final firstSet = a.runes.toSet();
    final secondSet = b.runes.toSet();
    final union = {...firstSet, ...secondSet};
    final intersection = firstSet.intersection(secondSet);
    final score = ((intersection.length / union.length) * 100).round();
    final label = score >= 70
        ? 'شباهت نوشتاری زیاد'
        : score >= 40
            ? 'شباهت نوشتاری متوسط'
            : 'شباهت نوشتاری کم';

    return CompatibilityResult(
      score: score,
      label: label,
      method: 'شاخص شفاف شباهت نوشتاری بر پایه نسبت حروف یکتای مشترک به اجتماع حروف. این Rule درباره عشق، ازدواج یا آینده ادعا نمی‌کند.',
      disclaimer: 'نتیجه این بخش یک شاخص زبانی آزمایشی است، نه سازگاری علمی یا پیش‌بینی رابطه.',
    );
  }
}
