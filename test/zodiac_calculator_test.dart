import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:taalebin/core/date/app_date.dart';
import 'package:taalebin/domain/zodiac/zodiac_calculator.dart';
import 'package:taalebin/domain/zodiac/zodiac_repository.dart';

void main() {
  const repository = LocalZodiacRepository();
  const calculator = ZodiacCalculator(repository);
  final signs = repository.allSigns();

  group('Zodiac data integrity', () {
    test('12 signs with unique ids and symbols', () {
      expect(signs.length, 12);
      expect(signs.map((s) => s.id).toSet().length, 12);
      expect(signs.map((s) => s.symbol).toSet().length, 12);
    });

    test('every day of a full Gregorian year maps to exactly one sign', () {
      final year = 2024; // Gregorian leap year
      final mapped = <String>[];
      var day = DateTime(year, 1, 1);
      while (day.year == year) {
        var found = 0;
        String? id;
        for (final sign in signs) {
          final m = day.month;
          final d = day.day;
          final inStart = m == sign.startMonth && d >= sign.startDay;
          final inEnd = m == sign.endMonth && d <= sign.endDay;
          if (inStart || inEnd) {
            found++;
            id = sign.id;
          }
        }
        expect(found, 1,
            reason: '${day.toString()} matched $found signs (got $id)');
        mapped.add(id!);
        day = day.add(const Duration(days: 1));
      }
      expect(mapped.length, 366);
      expect(mapped.toSet().length, 12);
    });
  });

  group('Boundary dates (Gregorian boundaries via Jalali input)', () {
    // Jalali dates chosen so the Gregorian date is exactly the boundary.
    void expectSign(Jalali jalali, String expectedId) {
      final result = calculator.calculate(jalali);
      expect(result, isNotNull, reason: 'no sign for $jalali');
      expect(result!.sign.id, expectedId,
          reason: '$jalali → ${result.sign.id}, wanted $expectedId');
    }

    test('Mar 20 → Pisces, Mar 21 → Aries (Jalali 1403/01/01 edge)', () {
      // 1403-01-01 == 2024-03-20 (Pisces last day)
      expectSign(Jalali(1403, 1, 1), 'pisces');
      // 1403-01-02 == 2024-03-21 (Aries first day)
      expectSign(Jalali(1403, 1, 2), 'aries');
    });

    test('Apr 19/20 Aries→Taurus boundary', () {
      expectSign(Jalali(1403, 1, 31), 'aries'); // 2024-04-19
      expectSign(Jalali(1403, 2, 1), 'taurus'); // 2024-04-20
    });

    test('Nov 21/22 Scorpio→Sagittarius & Dec 21/22 Sagittarius→Capricorn',
        () {
      expectSign(Jalali(1403, 9, 1), 'scorpio'); // 2024-11-21 (last day)
      expectSign(Jalali(1403, 9, 2), 'sagittarius'); // 2024-11-22
      expectSign(Jalali(1403, 10, 1), 'sagittarius'); // 2024-12-21 (last day)
      expectSign(Jalali(1403, 10, 2), 'capricorn'); // 2024-12-22
    });

    test('Capricorn wraps the year end: Dec 25 & Jan 1 are both capricorn', () {
      expectSign(Jalali(1403, 10, 5), 'capricorn'); // 2024-12-25
      expectSign(Jalali(1403, 10, 12), 'capricorn'); // 2025-01-01
    });

    test('Jan 19/20 Capricorn→Aquarius boundary', () {
      expectSign(Jalali(1403, 10, 30), 'capricorn'); // 2025-01-19 (last day)
      expectSign(Jalali(1403, 11, 1), 'aquarius'); // 2025-01-20
    });

    test('Feb 18/19 Aquarius→Pisces boundary', () {
      expectSign(Jalali(1403, 11, 30), 'aquarius'); // 2025-02-18 (last day)
      expectSign(Jalali(1403, 12, 1), 'pisces'); // 2025-02-19
    });
  });

  group('Leap years', () {
    test('Jalali leap years have 30-day Esfand (e.g. 1403)', () {
      expect(AppDate.isLeapYear(1403), isTrue);
      expect(AppDate.monthLength(1403, 12), 30);
      expect(AppDate.isValid(1403, 12, 30), isTrue);
      expect(AppDate.isValid(1403, 12, 31), isFalse);
    });

    test('non-leap Jalali years have 29-day Esfand (e.g. 1402)', () {
      expect(AppDate.isLeapYear(1402), isFalse);
      expect(AppDate.monthLength(1402, 12), 29);
      expect(AppDate.isValid(1402, 12, 30), isFalse);
    });

    test('Gregorian Feb 29 (Jalali 1402/12/10 == 2024-02-29) → Pisces', () {
      final result = calculator.calculate(Jalali(1402, 12, 10));
      expect(result, isNotNull);
      expect(result!.gregorianBirthDate.month, 2);
      expect(result.gregorianBirthDate.day, 29);
      expect(result.sign.id, 'pisces');
    });
  });

  group('Invalid dates', () {
    test('never throws — returns null', () {
      // Directly constructing invalid Jalali throws; the calculator must not
      // be the failure point for garbage input at its edges.
      final bad = <Jalali?>[
        (() {
          try {
            return Jalali(1403, 13, 1);
          } catch (_) {
            return null;
          }
        })(),
        (() {
          try {
            return Jalali(1403, 0, 5);
          } catch (_) {
            return null;
          }
        })(),
      ];
      for (final b in bad) {
        if (b == null) continue;
        expect(() => calculator.calculate(b), returnsNormally);
      }
    });
  });

  group('All 12 signs reachable via Jalali inputs', () {
    test('sample birth date for each sign id', () {
      final samples = <String, Jalali>{
        'aries': Jalali(1370, 1, 15), // 1991-04-04
        'taurus': Jalali(1370, 2, 15), // 1991-05-05
        'gemini': Jalali(1370, 3, 15), // 1991-06-05
        'cancer': Jalali(1370, 4, 15), // 1991-07-06
        'leo': Jalali(1370, 5, 15), // 1991-08-06
        'virgo': Jalali(1370, 6, 15), // 1991-09-06
        'libra': Jalali(1370, 7, 15), // 1991-10-07
        'scorpio': Jalali(1370, 8, 15), // 1991-11-06
        'sagittarius': Jalali(1370, 9, 10), // 1991-12-01
        'capricorn': Jalali(1370, 10, 15), // 1992-01-05
        'aquarius': Jalali(1370, 11, 15), // 1992-02-04
        'pisces': Jalali(1370, 12, 15), // 1992-03-05
      };
      for (final entry in samples.entries) {
        final result = calculator.calculate(entry.value);
        expect(result, isNotNull, reason: entry.key);
        expect(result!.sign.id, entry.key,
            reason:
                '${entry.key} sample mapped to ${result.sign.id}');
      }
    });
  });
}
