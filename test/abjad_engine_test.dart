import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/data/database/seed_data.dart';
import 'package:nameology_app/domain/engines/abjad_engine.dart';

void main() {
  final engine = AbjadEngine(mapping: abjadKabirLetters, sourceNote: 'test');

  test('calculates known Arabic/Persian-compatible letters', () {
    final result = engine.calculate('اب');
    expect(result.total, 3);
    expect(result.unknownLetters, isEmpty);
    expect(result.steps.map((step) => step.value), [1, 2]);
  });

  test('does not guess additional Persian letters', () {
    final result = engine.calculate('پ');
    expect(result.total, 0);
    expect(result.unknownLetters, contains('پ'));
    expect(result.isComplete, isFalse);
  });
}
