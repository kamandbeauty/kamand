import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/core/deterministic_seed.dart';

void main() {
  test('daily seed is deterministic for the same date and system', () {
    final date = DateTime(2026, 10, 6);
    final first = DeterministicSeed.forDay(name: 'آریا', localDate: date, systemKey: 'kabir');
    final second = DeterministicSeed.forDay(name: 'آریا', localDate: date, systemKey: 'kabir');
    final otherSystem = DeterministicSeed.forDay(name: 'آریا', localDate: date, systemKey: 'other');
    expect(first, second);
    expect(first, isNot(otherSystem));
  });
}
