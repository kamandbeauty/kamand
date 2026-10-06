/// A zodiac sign with its static, authored content.
///
/// Content itself lives in the data layer (`AppContent`); this model is the
/// domain-facing representation consumed by engines and UI.
class ZodiacSign {
  const ZodiacSign({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.symbol,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
    required this.element,
    required this.elementId,
    required this.rulingPlanet,
    required this.description,
    required this.personality,
    required this.strengths,
    required this.weaknesses,
    required this.loveStyle,
    required this.workStyle,
    required this.friendshipStyle,
    required this.luckyColors,
    required this.luckyNumbers,
    required this.luckyTimes,
    required this.dailyGeneral,
    required this.dailyLove,
    required this.dailyCareer,
    required this.dailyFinance,
    required this.dailyMood,
    required this.dailyWarning,
    required this.dailyOpportunity,
    required this.weeklySummaries,
    required this.monthlyFocus,
    required this.monthlyLove,
    required this.monthlyCareer,
    required this.monthlyFinance,
    required this.monthlyEnergy,
    required this.monthlyOpportunity,
    required this.monthlyWarning,
  });

  final String id;
  final String nameFa;
  final String nameEn;
  final String symbol;

  /// Gregorian boundary (inclusive). Capricorn wraps the year end.
  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;

  final String element; // فارسی: آتش / خاک / هوا / آب
  final String elementId; // fire / earth / air / water
  final String rulingPlanet;

  final String description;
  final String personality;
  final List<String> strengths;
  final List<String> weaknesses;
  final String loveStyle;
  final String workStyle;
  final String friendshipStyle;

  final List<String> luckyColors;
  final List<int> luckyNumbers;
  final List<String> luckyTimes;

  final List<String> dailyGeneral;
  final List<String> dailyLove;
  final List<String> dailyCareer;
  final List<String> dailyFinance;
  final List<String> dailyMood;
  final List<String> dailyWarning;
  final List<String> dailyOpportunity;

  final List<String> weeklySummaries;

  final List<String> monthlyFocus;
  final List<String> monthlyLove;
  final List<String> monthlyCareer;
  final List<String> monthlyFinance;
  final List<String> monthlyEnergy;
  final List<String> monthlyOpportunity;
  final List<String> monthlyWarning;

  /// "۲۱ فروردین تا ۲۰ اردیبهشت" (approximate Persian mapping for display).
  String get dateRangeFa {
    const monthNames = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
    ];
    return '${startDay} ${monthNames[startMonth - 1]} تا '
        '${endDay} ${monthNames[endMonth - 1]}';
  }
}
