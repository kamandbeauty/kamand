import 'package:shamsi_date/shamsi_date.dart';

import '../utils/persian_numbers.dart';

/// Central Solar-Hijri (Jalali) date abstraction.
///
/// Every date calculation in the app goes through this class — UI code never
/// manipulates Jalali/Gregorian conversions directly. Internal processing
/// uses Gregorian `DateTime` (via shamsi_date) while everything the user
/// sees is Solar Hijri with Persian digits.
class AppDate {
  AppDate._();

  static const List<String> monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  /// Week starting Saturday → index 0..6
  static const List<String> weekDayNames = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  static Jalali now() => Jalali.now();

  static Jalali fromYMD(int year, int month, int day) => Jalali(year, month, day);

  static Jalali fromGregorian(DateTime dateTime) => Jalali.fromDateTime(dateTime);

  static DateTime toGregorian(Jalali jalali) => jalali.toDateTime();

  /// Whether the given Jalali Y/M/D is a real date (guards user input).
  static bool isValid(int year, int month, int day) {
    if (month < 1 || month > 12) return false;
    if (day < 1) return false;
    try {
      final j = Jalali(year, month, day);
      return j.year == year && j.month == month && j.day == day;
    } catch (_) {
      return false;
    }
  }

  /// Days in a given Jalali month (handles leap-year Esfand correctly).
  static int monthLength(int year, int month) {
    if (month < 1 || month > 12) return 0;
    if (month <= 6) return 31;
    if (month <= 11) return 30;
    return isLeapYear(year) ? 30 : 29;
  }

  /// Leap-year check via shamsi_date's month arithmetic (authoritative):
  /// Esfand has 30 days exactly in leap years.
  static bool isLeapYear(int jalaliYear) {
    try {
      return Jalali(jalaliYear, 12, 1).monthLength == 30;
    } catch (_) {
      return false;
    }
  }

  static Jalali addDays(Jalali date, int days) =>
      Jalali.fromDateTime(date.toDateTime().add(Duration(days: days)));

  /// Persian weekday index, 0 = Saturday … 6 = Friday.
  static int weekDayIndex(Jalali date) {
    final g = date.toDateTime().weekday; // DateTime: Mon=1 … Sun=7
    return (g + 1) % 7; // Sat→0 … Fri→6
  }

  static String weekDayName(Jalali date) => weekDayNames[weekDayIndex(date)];

  /// Saturday that starts the week containing [date].
  static Jalali weekStart(Jalali date) => addDays(date, -weekDayIndex(date));

  /// Canonical day key used for cache identity: "1405-07-14".
  static String dayKey(Jalali date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// "۱۴ مرداد ۱۴۰۵"
  static String formatMedium(Jalali date) =>
      '${PersianNumbers.toPersian(date.day.toString())} '
      '${monthNames[date.month - 1]} '
      '${PersianNumbers.toPersian(date.year.toString())}';

  /// "سه‌شنبه ۱۴ مرداد ۱۴۰۵"
  static String formatFull(Jalali date) =>
      '${weekDayName(date)} ${formatMedium(date)}';

  /// "۱۴۰۵/۰۷/۱۴"
  static String formatShort(Jalali date) => PersianNumbers.toPersian(
        '${date.year}/${_two(date.month)}/${_two(date.day)}',
      );

  /// "۱۴۰۵/۰۷"
  static String formatYearMonth(Jalali date) => PersianNumbers.toPersian(
        '${date.year}/${_two(date.month)}',
      );

  /// Jalali years a person born on [birth] has lived (floor).
  static int ageInYears(Jalali birth, Jalali today) {
    var age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  /// Birth years offered in onboarding pickers (100 years back).
  static int get minBirthYear => now().year - 100;
  static int get maxBirthYear => now().year;
}
