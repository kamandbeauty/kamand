import '../../core/normalization/persian_normalizer.dart';
import '../models/abjad_result.dart';
import '../models/jafr_result.dart';
import '../models/numerology_rule.dart';

class JafrEngine {
  const JafrEngine({required this.mapping, this.rule});

  final Map<String, int> mapping;
  final NumerologyRule? rule;

  JafrResult calculate(String input) {
    final activeRule = rule ?? const NumerologyRule(
      systemKey: 'jafr-abjad',
      systemTitle: 'عدد جفر بر پایه علم حروف',
      ruleKey: 'jafr_abjad_sum',
      operation: 'jafr_abjad_sum',
      version: '1',
      status: 'unverified',
      disclaimer: 'این خروجی سنتی و تفسیری است و پیش‌بینی شخصیت، رابطه، سرنوشت یا آینده نیست.',
      sourceTitle: 'بدون منبع نهایی',
    );
    final normalized = PersianNormalizer.normalize(input);
    final steps = <AbjadStep>[];
    final unknown = <String>[];
    var total = 0;

    for (final rune in normalized.runes) {
      final letter = String.fromCharCode(rune);
      if (letter.trim().isEmpty) continue;
      final value = mapping[letter];
      steps.add(AbjadStep(letter: letter, normalizedLetter: letter, value: value));
      if (value == null) {
        if (!unknown.contains(letter)) unknown.add(letter);
      } else {
        total += value;
      }
    }

    if (steps.isEmpty || unknown.isNotEmpty) {
      return JafrResult(
        systemTitle: activeRule.systemTitle,
        ruleKey: activeRule.ruleKey,
        ruleVersion: activeRule.version,
        steps: steps,
        total: total,
        reducedValue: 0,
        unknownLetters: unknown,
        formula: activeRule.operation,
        description: unknown.isEmpty ? 'برای ورودی خالی عددی تولید نشد.' : 'حروف ناشناخته در نگاشت استاندارد جفر وجود دارد؛ مقدار آن‌ها حدس زده نمی‌شود.',
        disclaimer: activeRule.disclaimer,
        status: 'unknown',
        sourceTitle: activeRule.sourceTitle,
        calculation: 'نامشخص؛ ورودی کامل نیست',
        isAvailable: false,
      );
    }

    if (activeRule.operation != 'jafr_abjad_sum') {
      return JafrResult(
        systemTitle: activeRule.systemTitle,
        ruleKey: activeRule.ruleKey,
        ruleVersion: activeRule.version,
        steps: steps,
        total: total,
        reducedValue: 0,
        unknownLetters: const [],
        formula: activeRule.operation,
        description: 'عملیات Rule در JafrEngine پشتیبانی نمی‌شود؛ عددی حدس زده نشد.',
        disclaimer: activeRule.disclaimer,
        status: 'unknown',
        sourceTitle: activeRule.sourceTitle,
        calculation: 'نامشخص؛ عملیات ${activeRule.operation} پشتیبانی نمی‌شود',
        isAvailable: false,
      );
    }

    final reduced = _digitalRoot(total);
    return JafrResult(
      systemTitle: activeRule.systemTitle,
      ruleKey: activeRule.ruleKey,
      ruleVersion: activeRule.version,
      steps: steps,
      total: total,
      reducedValue: reduced,
      unknownLetters: const [],
      formula: activeRule.operation,
      description: 'در این نسخه فقط جمع ارزش عددی حروف محاسبه می‌شود. کاهش رقمی یک مقدار مشتق‌شده برای نمایش است و تفسیر جفری یا پیش‌بینی آینده تولید نمی‌کند.',
      disclaimer: activeRule.disclaimer,
      status: activeRule.status,
      sourceTitle: activeRule.sourceTitle,
      calculation: '$total → کاهش رقمی مشتق‌شده: $reduced',
      isAvailable: true,
    );
  }

  int _digitalRoot(int value) {
    if (value <= 9) return value;
    var current = value;
    while (current > 9) {
      current = current.toString().split('').map(int.parse).fold(0, (sum, digit) => sum + digit);
    }
    return current;
  }
}
