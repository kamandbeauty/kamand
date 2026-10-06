import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/core/calendar/date_engine.dart';

void main() {
  test('converts Gregorian new year to Jalali new year', () {
    final result = DateEngine.gregorianToJalali(DateTime(2024, 3, 20));
    expect(result.iso, '1403-01-01');
  });

  test('converts Jalali new year back to Gregorian', () {
    final result = DateEngine.jalaliToGregorian(const CalendarDate(year: 1403, month: 1, day: 1, calendar: CalendarKind.jalali));
    expect(result.year, 2024);
    expect(result.month, 3);
    expect(result.day, 20);
  });

  test('birth number is deterministic', () {
    const date = CalendarDate(year: 1403, month: 1, day: 1, calendar: CalendarKind.jalali);
    expect(DateEngine.birthNumber(date), 9);
    expect(DateEngine.lifePath(birthDate: date), 9);
  });

  test('validates calendar dates before conversion', () {
    expect(DateEngine.isValid(const CalendarDate(year: 1403, month: 13, day: 1, calendar: CalendarKind.jalali)), isFalse);
    expect(DateEngine.isValid(const CalendarDate(year: 1402, month: 12, day: 30, calendar: CalendarKind.jalali)), isFalse);
    expect(DateEngine.isValid(const CalendarDate(year: 2024, month: 2, day: 29, calendar: CalendarKind.gregorian)), isTrue);
    expect(DateEngine.isValid(const CalendarDate(year: 2023, month: 2, day: 29, calendar: CalendarKind.gregorian)), isFalse);
  });
}
