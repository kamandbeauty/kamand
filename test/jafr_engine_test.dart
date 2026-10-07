import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/domain/engines/jafr_engine.dart';
import 'package:nameology_app/domain/models/numerology_rule.dart';

void main() {
  const rule = NumerologyRule(
    systemKey: 'jafr-abjad',
    systemTitle: 'عدد جفر بر پایه علم حروف',
    ruleKey: 'jafr_abjad_sum',
    operation: 'jafr_abjad_sum',
    version: '1',
    status: 'unverified',
    disclaimer: 'این خروجی سنتی و تفسیری است.',
    sourceTitle: 'Iranica',
  );
  const engine = JafrEngine(mapping: {'ا': 1, 'ب': 2, 'ج': 3, 'د': 4}, rule: rule);

  test('calculates sourced letter sum and derived digital root', () {
    final result = engine.calculate('ابد');
    expect(result.isAvailable, isTrue);
    expect(result.total, 7);
    expect(result.reducedValue, 7);
    expect(result.status, 'unverified');
    expect(result.calculation, contains('کاهش رقمی مشتق‌شده'));
  });

  test('does not guess a Persian letter missing from the standard mapping', () {
    final result = engine.calculate('اپ');
    expect(result.isAvailable, isFalse);
    expect(result.status, 'unknown');
    expect(result.unknownLetters, contains('پ'));
  });

  test('does not infer future or personality from a Jafr number', () {
    final result = engine.calculate('ابدد');
    expect(result.description, contains('تفسیر جفری'));
    expect(result.disclaimer, contains('تفسیری'));
  });
}
