import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/domain/engines/compatibility_engine.dart';

void main() {
  const engine = CompatibilityEngine();

  test('same written form has maximum similarity', () {
    final result = engine.compareWrittenForm('آریا', 'آریا');
    expect(result.score, 100);
  });

  test('empty input has no score', () {
    final result = engine.compareWrittenForm('', 'آریا');
    expect(result.score, isNull);
  });
}
