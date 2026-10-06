import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:factor_ruby/core/date/app_date.dart';
import 'package:factor_ruby/core/utils/persian_numbers.dart';

void main() {
  group('Jalali ↔ Gregorian conversion (known dates)', () {
    test('1405-07-15 == 2026-10-06 (Tuesday)', () {
      final j = Jalali(1405, 7, 15);
      final g = AppDate.toGregorian(j);
      expect(g.year, 2026);
      expect(g.month, 10);
      expect(g.day, 6);
      expect(g.weekday, DateTime.tuesday);
    });

    test('round-trip for a whole year', () {
      var j = Jalali(1403, 1, 1);
      for (var i = 0; i < 366; i++) {
        final g = AppDate.toGregorian(j);
        final back = AppDate.fromGregorian(g);
        expect(back, j);
        j = AppDate.addDays(j, 1);
      }
      expect(j, Jalali(1404, 1, 1));
    });
  });

  group('Week helpers', () {
    test('weekday names & indices', () {
      // 1405-07-12 == 2026-10-03 == Saturday
      expect(AppDate.weekDayName(Jalali(1405, 7, 12)), 'شنبه');
      expect(AppDate.weekDayIndex(Jalali(1405, 7, 12)), 0);
      // 1405-07-15 == Tuesday → سه‌شنبه
      expect(AppDate.weekDayName(Jalali(1405, 7, 15)), 'سه‌شنبه');
      expect(AppDate.weekDayIndex(Jalali(1405, 7, 15)), 3);
      // Friday end of week
      expect(AppDate.weekDayName(Jalali(1405, 7, 18)), 'جمعه');
      expect(AppDate.weekDayIndex(Jalali(1405, 7, 18)), 6);
    });

    test('weekStart lands on Saturday for any date', () {
      for (var i = 0; i < 40; i++) {
        final d = AppDate.addDays(Jalali(1405, 7, 12), i);
        final start = AppDate.weekStart(d);
        expect(AppDate.weekDayIndex(start), 0, reason: '$d');
        expect(start.compareTo(d) <= 0, isTrue);
        expect(AppDate.addDays(d, -7).compareTo(start) < 0, isTrue);
      }
    });
  });

  group('Formatting (Persian digits)', () {
    test('formatMedium / formatFull', () {
      final j = Jalali(1405, 7, 15);
      expect(AppDate.formatMedium(j), '۱۵ مهر ۱۴۰۵');
      expect(AppDate.formatFull(j), 'سه‌شنبه ۱۵ مهر ۱۴۰۵');
    });

    test('formatShort & dayKey', () {
      final j = Jalali(1405, 7, 4);
      expect(AppDate.formatShort(j), '۱۴۰۵/۰۷/۰۴');
      expect(AppDate.dayKey(j), '1405-07-04');
    });

    test('month names', () {
      expect(AppDate.monthNames[0], 'فروردین');
      expect(AppDate.monthNames[6], 'مهر');
      expect(AppDate.monthNames[11], 'اسفند');
    });

    test('age calculation', () {
      expect(AppDate.ageInYears(Jalali(1370, 7, 15), Jalali(1405, 7, 15)), 35);
      expect(AppDate.ageInYears(Jalali(1370, 7, 16), Jalali(1405, 7, 15)), 34);
    });
  });

  group('PersianNumbers', () {
    test('digit conversion', () {
      expect(PersianNumbers.toPersian('1405'), '۱۴۰۵');
      expect(PersianNumbers.toPersian('82%'), '۸۲٪'.replaceAll('٪', '%'));
      expect(PersianNumbers.toPersian('a1b2'), 'a۱b۲');
    });

    test('percent display', () {
      expect(PersianNumbers.percent(82), '۸۲٪');
    });

    test('twoDigits', () {
      expect(PersianNumbers.twoDigits(5), '۰۵');
      expect(PersianNumbers.twoDigits(15), '۱۵');
    });

    test('parse Persian digits back', () {
      expect(PersianNumbers.tryParse('۱۴۰۵'), 1405);
      expect(PersianNumbers.tryParse('۸۲'), 82);
      expect(PersianNumbers.tryParse('abc'), isNull);
    });

    test('thousand separator', () {
      expect(PersianNumbers.format(1400), '۱٬۴۰۰');
    });
  });

  group('Validity & leap years', () {
    test('isValid', () {
      expect(AppDate.isValid(1403, 12, 30), isTrue);
      expect(AppDate.isValid(1402, 12, 30), isFalse);
      expect(AppDate.isValid(1403, 7, 31), isFalse); // Mehr has 30 days
      expect(AppDate.isValid(1403, 1, 31), isTrue);
      expect(AppDate.isValid(1403, 0, 10), isFalse);
    });

    test('leap year matches shamsi_date across a century', () {
      for (var y = 1300; y <= 1500; y++) {
        expect(AppDate.isLeapYear(y), Jalali.isLeap(y), reason: 'year $y');
      }
    });
  });
}
