import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/domain/engines/compatibility_engine.dart';
import 'package:nameology_app/domain/models/compatibility_rule.dart';

void main() {
  const engine = CompatibilityEngine();

  test('same written form has maximum similarity', () {
    final result = engine.compareWrittenForm('آریا', 'آریا');
    expect(result.score, 100);
    expect(result.ruleKey, 'unique_letter_jaccard');
    expect(result.ruleVersion, '1');
    expect(result.status, 'unverified');
    expect(result.calculation, contains('100%'));
  });

  test('empty input has no score', () {
    final result = engine.compareWrittenForm('', 'آریا');
    expect(result.score, isNull);
    expect(result.calculation, contains('نامشخص'));
  });

  test('unsupported operation never guesses a score', () {
    const unsupported = CompatibilityRule(
      systemKey: 'test',
      systemTitle: 'test',
      ruleKey: 'future',
      operation: 'future_operation',
      version: '9',
      status: 'unverified',
      disclaimer: 'test',
      sourceTitle: 'Unknown',
    );
    final result = CompatibilityEngine(rule: unsupported).compareWrittenForm('آریا', 'سام');
    expect(result.score, isNull);
    expect(result.isAvailable, isFalse);
  });
}
