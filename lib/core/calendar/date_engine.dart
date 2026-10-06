import '../normalization/persian_normalizer.dart';

enum CalendarKind { gregorian, jalali }

class CalendarDate {
  const CalendarDate({required this.year, required this.month, required this.day, required this.calendar});

  final int year;
  final int month;
  final int day;
  final CalendarKind calendar;

  String get iso => '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  String toString() => iso;
}

class DateEngine {
  const DateEngine._();

  static CalendarDate gregorianToJalali(DateTime date) {
    var gy = date.year - 1600;
    final gm = date.month - 1;
    final gd = date.day - 1;
    var gDayNo = 365 * gy + ((gy + 3) ~/ 4) - ((gy + 99) ~/ 100) + ((gy + 399) ~/ 400);
    const gDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    for (var i = 0; i < gm; i++) {
      gDayNo += gDays[i];
    }
    if (gm > 1 && ((date.year % 4 == 0 && date.year % 100 != 0) || date.year % 400 == 0)) {
      gDayNo++;
    }
    gDayNo += gd;

    var jDayNo = gDayNo - 79;
    final jNp = jDayNo ~/ 12053;
    jDayNo %= 12053;
    var jy = 979 + 33 * jNp + 4 * (jDayNo ~/ 1461);
    jDayNo %= 1461;
    if (jDayNo >= 366) {
      jy += (jDayNo - 1) ~/ 365;
      jDayNo = (jDayNo - 1) % 365;
    }
    final jm = jDayNo < 186 ? 1 + jDayNo ~/ 31 : 7 + (jDayNo - 186) ~/ 30;
    final jd = 1 + (jDayNo < 186 ? jDayNo % 31 : (jDayNo - 186) % 30);
    return CalendarDate(year: jy, month: jm, day: jd, calendar: CalendarKind.jalali);
  }

  static DateTime jalaliToGregorian(CalendarDate date) {
    if (date.calendar != CalendarKind.jalali) {
      return DateTime(date.year, date.month, date.day);
    }
    var jy = date.year - 979;
    final jm = date.month - 1;
    final jd = date.day - 1;
    var jDayNo = 365 * jy + (jy ~/ 33) * 8 + ((jy % 33) + 3) ~/ 4;
    const jDays = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29];
    for (var i = 0; i < jm; i++) {
      jDayNo += jDays[i];
    }
    jDayNo += jd;

    var gDayNo = jDayNo + 79;
    var gy = 1600 + 400 * (gDayNo ~/ 146097);
    gDayNo %= 146097;
    var leap = true;
    if (gDayNo >= 36525) {
      gDayNo--;
      gy += 100 * (gDayNo ~/ 36524);
      gDayNo %= 36524;
      if (gDayNo >= 365) {
        gDayNo++;
      } else {
        leap = false;
      }
    }
    gy += 4 * (gDayNo ~/ 1461);
    gDayNo %= 1461;
    if (gDayNo >= 366) {
      leap = false;
      gDayNo--;
      gy += gDayNo ~/ 365;
      gDayNo %= 365;
    }
    final gDays = [31, if (leap) 29 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var gm = 0;
    while (gm < 12 && gDayNo >= gDays[gm]) {
      gDayNo -= gDays[gm];
      gm++;
    }
    return DateTime(gy, gm + 1, gDayNo + 1);
  }

  static CalendarDate nowJalali() => gregorianToJalali(DateTime.now());

  static CalendarDate? parse(String input, CalendarKind calendar) {
    final normalized = PersianNormalizer.toLatinDigits(input.trim()).replaceAll('/', '-');
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(normalized);
    if (match == null) return null;
    final date = CalendarDate(year: int.parse(match.group(1)!), month: int.parse(match.group(2)!), day: int.parse(match.group(3)!), calendar: calendar);
    return isValid(date) ? date : null;
  }

  static bool isValid(CalendarDate date) {
    if (date.year < 1 || date.month < 1 || date.month > 12 || date.day < 1) return false;
    if (date.calendar == CalendarKind.jalali) {
      final maxDay = date.month <= 6 ? 31 : date.month <= 11 ? 30 : 30;
      if (date.day > maxDay) return false;
      final converted = jalaliToGregorian(date);
      final roundTrip = gregorianToJalali(converted);
      return roundTrip.year == date.year && roundTrip.month == date.month && roundTrip.day == date.day;
    }
    final converted = DateTime(date.year, date.month, date.day);
    return converted.year == date.year && converted.month == date.month && converted.day == date.day;
  }

  static int digitSum(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '').split('').fold(0, (sum, digit) => sum + int.parse(digit));
  }

  static int reduceToSingleDigit(int value) {
    var result = value.abs();
    while (result > 9) {
      result = digitSum(result.toString());
    }
    return result;
  }

  static int birthNumber(CalendarDate date) => reduceToSingleDigit(digitSum(date.iso));

  static int lifePath({required CalendarDate birthDate}) => reduceToSingleDigit(digitSum(birthDate.iso));
}
