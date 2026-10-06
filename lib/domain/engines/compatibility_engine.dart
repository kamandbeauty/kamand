import '../../core/normalization/persian_normalizer.dart';
import '../models/compatibility_result.dart';
import '../models/compatibility_rule.dart';

class CompatibilityEngine {
  const CompatibilityEngine({this.rule});

  final CompatibilityRule? rule;

  CompatibilityResult compareWrittenForm(String first, String second) {
    final activeRule = rule ?? const CompatibilityRule(
      systemKey: 'written-form-similarity',
      systemTitle: 'شاخص شباهت نوشتاری',
      ruleKey: 'unique_letter_jaccard',
      operation: 'unique_letter_jaccard',
      version: '1',
      status: 'unverified',
      disclaimer: 'این شاخص فقط شباهت نوشتاری دو ورودی را نشان می‌دهد و سازگاری علمی، عاطفی یا پیش‌بینی رابطه نیست.',
      sourceTitle: 'روش داخلی آزمایشی',
    );
    final a = _normalize(first);
    final b = _normalize(second);
    if (a.isEmpty || b.isEmpty) {
      return _result(
        activeRule,
        score: null,
        label: 'برای مقایسه دو نام کافی نیست',
        method: 'هر دو ورودی باید دارای حداقل یک حرف باشند.',
        calculation: 'نامشخص؛ ورودی کامل نیست',
      );
    }
    if (activeRule.operation != 'unique_letter_jaccard') {
      return _result(
        activeRule,
        score: null,
        label: 'نتیجه نامشخص است',
        method: 'عملیات این Rule در Engine شناخته‌شده نیست؛ عددی تولید نشد.',
        calculation: 'نامشخص؛ عملیات ${activeRule.operation} پشتیبانی نمی‌شود',
        available: false,
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

    return _result(
      activeRule,
      score: score,
      label: label,
      method: 'شاخص شفاف شباهت نوشتاری بر پایه نسبت حروف یکتای مشترک به اجتماع حروف.',
      calculation: '|اشتراک| / |اجتماع| × 100 = ${intersection.length} / ${union.length} × 100 = $score%',
    );
  }

  String _normalize(String value) => PersianNormalizer.normalizeForSearch(value).replaceAll(' ', '');

  CompatibilityResult _result(
    CompatibilityRule activeRule, {
    required int? score,
    required String label,
    required String method,
    required String calculation,
    bool available = true,
  }) {
    return CompatibilityResult(
      score: score,
      label: label,
      method: method,
      disclaimer: activeRule.disclaimer,
      ruleKey: activeRule.ruleKey,
      ruleVersion: activeRule.version,
      calculation: calculation,
      status: available ? activeRule.status : 'unknown',
      sourceTitle: activeRule.sourceTitle,
      isAvailable: available,
    );
  }
}
