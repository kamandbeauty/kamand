import 'package:shamsi_date/shamsi_date.dart';

import 'zodiac_repository.dart';
import 'zodiac_sign.dart';

/// Result of a birth-date → zodiac computation.
class ZodiacCalculation {
  const ZodiacCalculation({
    required this.sign,
    required this.gregorianBirthDate,
    required this.jalaliBirthDate,
  });

  final ZodiacSign sign;
  final DateTime gregorianBirthDate;
  final Jalali jalaliBirthDate;
}

/// Independent, fully unit-tested service that maps a Solar-Hijri birth
/// date to its zodiac sign.
///
/// The tropical zodiac boundaries are evaluated on the Gregorian date
/// (internal processing), converted from the Jalali input.
class ZodiacCalculator {
  const ZodiacCalculator(this._repository);

  final ZodiacRepository _repository;

  /// Computes the sign for a Jalali birth date.
  ///
  /// Returns null for invalid dates (caller decides how to surface the
  /// error — the calculator never throws for bad input).
  ZodiacCalculation? calculate(Jalali birthDate) {
    DateTime gregorian;
    try {
      gregorian = birthDate.toDateTime();
    } catch (_) {
      return null;
    }
    final month = gregorian.month;
    final day = gregorian.day;
    for (final sign in _repository.allSigns()) {
      if (_matches(sign, month, day)) {
        return ZodiacCalculation(
          sign: sign,
          gregorianBirthDate: gregorian,
          jalaliBirthDate: birthDate,
        );
      }
    }
    return null;
  }

  static bool _matches(ZodiacSign sign, int month, int day) {
    final inStart = month == sign.startMonth && day >= sign.startDay;
    final inEnd = month == sign.endMonth && day <= sign.endDay;
    return inStart || inEnd;
  }
}
