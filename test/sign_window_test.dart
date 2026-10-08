import 'package:flutter_test/flutter_test.dart';
import 'package:taalebin/domain/zodiac/sign_window.dart';

/// Window math for the home screen's sign date-range line (v1.10.1).
void main() {
  group('signWindow — the window containing today, or the next one', () {
    test('Capricorn in January → last December to this January', () {
      final (s, e) = signWindow(
        startMonth: 12, startDay: 22,
        endMonth: 1, endDay: 19,
        today: DateTime(2027, 1, 5),
      );
      expect(s, DateTime(2026, 12, 22));
      expect(e, DateTime(2027, 1, 19));
    });

    test('Capricorn on the boundary day itself', () {
      final (s, e) = signWindow(
        startMonth: 12, startDay: 22,
        endMonth: 1, endDay: 19,
        today: DateTime(2026, 12, 22),
      );
      expect(s, DateTime(2026, 12, 22));
      expect(e, DateTime(2027, 1, 19));
    });

    test('Capricorn in October → the upcoming window', () {
      final (s, e) = signWindow(
        startMonth: 12, startDay: 22,
        endMonth: 1, endDay: 19,
        today: DateTime(2026, 10, 8),
      );
      expect(s, DateTime(2026, 12, 22));
      expect(e, DateTime(2027, 1, 19));
    });

    test('Aries in January → this year\'s upcoming window', () {
      final (s, e) = signWindow(
        startMonth: 3, startDay: 21,
        endMonth: 4, endDay: 20,
        today: DateTime(2027, 1, 5),
      );
      expect(s, DateTime(2027, 3, 21));
      expect(e, DateTime(2027, 4, 20));
    });

    test('Leo in August (inside) → same-year window', () {
      final (s, e) = signWindow(
        startMonth: 7, startDay: 23,
        endMonth: 8, endDay: 22,
        today: DateTime(2026, 8, 10),
      );
      expect(s, DateTime(2026, 7, 23));
      expect(e, DateTime(2026, 8, 22));
    });

    test('Aries in June (past) → rolls to next year', () {
      final (s, e) = signWindow(
        startMonth: 3, startDay: 21,
        endMonth: 4, endDay: 20,
        today: DateTime(2026, 6, 1),
      );
      expect(s, DateTime(2027, 3, 21));
      expect(e, DateTime(2027, 4, 20));
    });
  });
}
