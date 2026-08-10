import 'package:shamsi_date/shamsi_date.dart';
import 'persian_number_formatter.dart';

class JalaliHelper {
  static String getTodayJalali() {
    final now = Jalali.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  static String formatJalali(Jalali date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return PersianNumberFormatter.toPersian('$year/$month/$day');
  }
}
