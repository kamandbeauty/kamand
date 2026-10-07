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
    expect(result.isComplete, isFalse);
    expect(result.status, 'unknown');
    expect(result.unknownLetters, contains('پ'));
  });

  test('keeps an empty input unavailable', () {
    final result = engine.calculate('   ');
    expect(result.isAvailable, isFalse);
    expect(result.isComplete, isFalse);
    expect(result.calculation, contains('نامشخص'));
  });

  test('does not infer future or personality from a Jafr number', () {
    final result = engine.calculate('ابدد');
    expect(result.description, contains('تفسیر جفری'));
    expect(result.disclaimer, contains('تفسیری'));
  });

  test('honors the stored reduction configuration', () {
    const noReduction = NumerologyRule(
      systemKey: 'jafr-abjad',
      systemTitle: 'عدد جفر بر پایه علم حروف',
      ruleKey: 'jafr_abjad_sum',
      operation: 'jafr_abjad_sum',
      configurationJson: '{"base_system":"kabir","reduction":"none"}',
      version: '2',
      status: 'unverified',
      disclaimer: 'test',
      sourceTitle: 'test',
    );
    final result = JafrEngine(mapping: const {'ا': 1, 'ب': 2, 'د': 4}, rule: noReduction).calculate('ابدد');
    expect(result.isAvailable, isTrue);
    expect(result.total, 11);
    expect(result.reducedValue, 0);
    expect(result.calculation, '11');
  });

  test('does not guess an unsupported reduction configuration', () {
    const unsupported = NumerologyRule(
      systemKey: 'jafr-abjad',
      systemTitle: 'عدد جفر بر پایه علم حروف',
      ruleKey: 'jafr_abjad_sum',
      operation: 'jafr_abjad_sum',
      configurationJson: '{"base_system":"kabir","reduction":"future_interpretation"}',
      version: '2',
      status: 'unverified',
      disclaimer: 'test',
      sourceTitle: 'test',
    );
    final result = JafrEngine(mapping: const {'ا': 1, 'ب': 2}, rule: unsupported).calculate('اب');
    expect(result.isAvailable, isFalse);
    expect(result.calculation, contains('پشتیبانی نمی‌شود'));
  });
}
