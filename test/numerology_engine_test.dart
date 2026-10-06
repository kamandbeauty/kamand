import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/domain/engines/numerology_engine.dart';

void main() {
  const engine = NumerologyEngine();

  test('reduces a total to one digit deterministically', () {
    expect(engine.fromAbjadTotal(0).value, 0);
    expect(engine.fromAbjadTotal(28).value, 1);
    expect(engine.fromAbjadTotal(999).value, 9);
  });
}
