/// Gregorian date-window math for zodiac signs.
///
/// A sign's boundaries are fixed Gregorian month/day pairs; Capricorn
/// (and any wrapping sign) spans the year end. This helper returns the
/// window that either *contains* [today] or is the next upcoming one —
/// so a Capricorn user in January sees last-December→this-January, not a
/// future window, and a past window rolls to next year.
(DateTime, DateTime) signWindow({
  required int startMonth,
  required int startDay,
  required int endMonth,
  required int endDay,
  required DateTime today,
}) {
  final wraps = endMonth < startMonth ||
      (endMonth == startMonth && endDay < startDay);

  if (wraps) {
    final prevStart = DateTime(today.year - 1, startMonth, startDay);
    final prevEnd = DateTime(today.year, endMonth, endDay);
    final inPrev = !today.isBefore(prevStart) && !today.isAfter(prevEnd);
    if (inPrev) return (prevStart, prevEnd);
    return (
      DateTime(today.year, startMonth, startDay),
      DateTime(today.year + 1, endMonth, endDay),
    );
  }

  var start = DateTime(today.year, startMonth, startDay);
  var end = DateTime(today.year, endMonth, endDay);
  if (today.isAfter(end)) {
    start = DateTime(today.year + 1, startMonth, startDay);
    end = DateTime(today.year + 1, endMonth, endDay);
  }
  return (start, end);
}
