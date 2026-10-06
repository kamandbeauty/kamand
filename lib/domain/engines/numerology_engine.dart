import '../models/numerology_result.dart';
import '../models/numerology_rule.dart';

class NumerologyEngine {
  const NumerologyEngine({this.rule});

  final NumerologyRule? rule;

  NumerologyResult fromAbjadTotal(int total, {bool inputComplete = true}) {
    final activeRule = rule ?? const NumerologyRule(
      systemKey: 'abjad-digital-root',
      systemTitle: 'کاهش رقمی بر پایه مجموع ابجد',
      ruleKey: 'digit_sum_reduce',
      operation: 'digit_sum_reduce',
      version: '1',
      status: 'unverified',
      disclaimer: 'این نتیجه سنتی و تفسیری است و پیش‌بینی علمی شخصیت یا آینده محسوب نمی‌شود.',
      sourceTitle: 'بدون منبع نهایی',
    );
    if (!inputComplete) {
      return NumerologyResult(
        value: 0,
        title: 'عدد سنتی نام: نامشخص',
        description: 'به‌دلیل وجود حرف ناشناخته، عددی تولید نشد.',
        systemTitle: activeRule.systemTitle,
        disclaimer: activeRule.disclaimer,
        ruleKey: activeRule.ruleKey,
        ruleVersion: activeRule.version,
        calculation: 'نامشخص؛ ورودی کامل نیست',
        status: 'unknown',
        sourceTitle: activeRule.sourceTitle,
        isAvailable: false,
      );
    }
    final value = _apply(activeRule.operation, total);
    if (value == null) {
      return NumerologyResult(
        value: 0,
        title: 'عدد سنتی نام: نامشخص',
        description: 'عملیات این Rule در Engine شناخته‌شده نیست؛ عددی تولید نشد.',
        systemTitle: activeRule.systemTitle,
        disclaimer: activeRule.disclaimer,
        ruleKey: activeRule.ruleKey,
        ruleVersion: activeRule.version,
        calculation: 'نامشخص؛ عملیات ${activeRule.operation} پشتیبانی نمی‌شود',
        status: 'unknown',
        sourceTitle: activeRule.sourceTitle,
        isAvailable: false,
      );
    }
    final calculation = '$total → ${_digits(total).join(' + ')} → $value';
    return NumerologyResult(
      value: value,
      title: 'عدد سنتی نام: $value',
      description: 'تفسیر منبع‌دار این عدد هنوز در آرشیو محتوایی ثبت نشده است. در این نسخه فقط مقدار محاسبه‌شده نمایش داده می‌شود.',
      systemTitle: activeRule.systemTitle,
      disclaimer: activeRule.disclaimer,
      ruleKey: activeRule.ruleKey,
      ruleVersion: activeRule.version,
      calculation: calculation,
      status: activeRule.status,
      sourceTitle: activeRule.sourceTitle,
    );
  }

  int? _apply(String operation, int value) {
    switch (operation) {
      case 'digit_sum_reduce':
        return _reduce(value);
      default:
        return null;
    }
  }

  int _reduce(int value) {
    if (value <= 9) return value;
    var current = value;
    while (current > 9) {
      current = _digits(current).fold(0, (sum, digit) => sum + digit);
    }
    return current;
  }

  List<int> _digits(int value) => value.abs().toString().split('').map(int.parse).toList(growable: false);
}
