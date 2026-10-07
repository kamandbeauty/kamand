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

  test('calculates the derived small and medium variants from the stored mapping', () {
    final saghir = AbjadEngine(mapping: abjadSaghirLetters, systemKey: 'saghir', sourceNote: 'test').calculate('یغ');
    final wasit = AbjadEngine(mapping: abjadWasitLetters, systemKey: 'wasit', sourceNote: 'test').calculate('یر');
    expect(saghir.steps.map((step) => step.value), [1, 1]);
    expect(saghir.total, 2);
    expect(wasit.steps.map((step) => step.value), [10, 8]);
    expect(wasit.total, 18);
  });

  test('keeps Persian equivalence separate from the standard system', () {
    final result = AbjadEngine(mapping: abjadKabirPersianLetters, systemKey: 'kabir-persian', sourceNote: 'test').calculate('پچژگ');
    expect(result.unknownLetters, isEmpty);
    expect(result.total, 32);
  });

  test('supports square and positional archive formulas', () {
    final akbar = AbjadEngine(mapping: abjadAkbarLetters, systemKey: 'akbar', sourceNote: 'test').calculate('ی');
    final wazee = AbjadEngine(mapping: abjadWazeeLetters, systemKey: 'wazee', sourceNote: 'test').calculate('ابجد');
    expect(akbar.total, 100);
    expect(wazee.steps.map((step) => step.value), [1, 2, 3, 4]);
  });
}
