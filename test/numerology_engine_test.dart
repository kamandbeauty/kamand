import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/domain/engines/numerology_engine.dart';
import 'package:nameology_app/domain/models/numerology_rule.dart';

void main() {
  const engine = NumerologyEngine();

  test('reduces a total to one digit deterministically', () {
    expect(engine.fromAbjadTotal(0).value, 0);
    expect(engine.fromAbjadTotal(28).value, 1);
    expect(engine.fromAbjadTotal(999).value, 9);
  });

  test('does not calculate a number from an incomplete abjad input', () {
    final result = engine.fromAbjadTotal(28, inputComplete: false);
    expect(result.isAvailable, isFalse);
    expect(result.status, 'unknown');
    expect(result.calculation, contains('نامشخص'));
  });

  test('does not guess an unsupported operation', () {
    const unsupported = NumerologyRule(systemKey: 'test', systemTitle: 'test', ruleKey: 'future', operation: 'future_operation', version: '9', status: 'unverified', disclaimer: 'test', sourceTitle: 'Unknown');
    final result = NumerologyEngine(rule: unsupported).fromAbjadTotal(28);
    expect(result.isAvailable, isFalse);
    expect(result.calculation, contains('پشتیبانی نمی‌شود'));
  });
}
