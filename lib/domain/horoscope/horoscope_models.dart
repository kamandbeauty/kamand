import 'package:shamsi_date/shamsi_date.dart';

/// All deterministic scores for one day. Range 0..100 each.
class DailyScores {
  const DailyScores({
    required this.love,
    required this.career,
    required this.finance,
    required this.mood,
    required this.energy,
  });

  final int love;
  final int career;
  final int finance;
  final int mood;
  final int energy;

  int get overall {
    final v = (love * 0.28 +
            career * 0.26 +
            finance * 0.18 +
            mood * 0.14 +
            energy * 0.14)
        .round();
    return v < 0 ? 0 : (v > 100 ? 100 : v);
  }
}

/// Lucky indicators for a day (deterministic per sign+date).
class LuckyInfo {
  const LuckyInfo({
    required this.color,
    required this.number,
    required this.time,
  });

  final String color;
  final int number;
  final String time;
}

/// The fully generated daily horoscope — the unit cached in the database.
class DailyHoroscope {
  const DailyHoroscope({
    required this.zodiacId,
    required this.date,
    required this.scores,
    required this.lucky,
    required this.generalText,
    required this.loveText,
    required this.careerText,
    required this.financeText,
    required this.moodText,
    required this.warningText,
    required this.opportunityText,
    required this.generatedVersion,
  });

  final String zodiacId;

  /// Canonical Jalali day key "1405-07-14".
  final String date;
  final DailyScores scores;
  final LuckyInfo lucky;

  final String generalText;
  final String loveText;
  final String careerText;
  final String financeText;
  final String moodText;
  final String warningText;
  final String opportunityText;
  final int generatedVersion;
}

/// One day's row inside the weekly view.
class WeeklyDay {
  const WeeklyDay({
    required this.date,
    required this.scores,
  });

  final Jalali date;
  final DailyScores scores;
}

class WeeklyHoroscope {
  const WeeklyHoroscope({
    required this.zodiacId,
    required this.weekStart,
    required this.days,
    required this.summaryText,
  });

  final String zodiacId;
  final Jalali weekStart; // Saturday
  final List<WeeklyDay> days; // 7 days Sat..Fri
  final String summaryText;

  DailyScores get average {
    var love = 0, career = 0, finance = 0, mood = 0, energy = 0;
    for (final d in days) {
      love += d.scores.love;
      career += d.scores.career;
      finance += d.scores.finance;
      mood += d.scores.mood;
      energy += d.scores.energy;
    }
    final n = days.length == 0 ? 1 : days.length;
    return DailyScores(
      love: (love / n).round(),
      career: (career / n).round(),
      finance: (finance / n).round(),
      mood: (mood / n).round(),
      energy: (energy / n).round(),
    );
  }
}

class MonthlyHoroscope {
  const MonthlyHoroscope({
    required this.zodiacId,
    required this.year,
    required this.month,
    required this.scores,
    required this.focusText,
    required this.loveText,
    required this.careerText,
    required this.financeText,
    required this.energyText,
    required this.opportunityText,
    required this.warningText,
  });

  final String zodiacId;
  final int year; // Jalali year
  final int month; // Jalali month 1..12
  final DailyScores scores;
  final String focusText;
  final String loveText;
  final String careerText;
  final String financeText;
  final String energyText;
  final String opportunityText;
  final String warningText;
}

/// Short one-line description used on the home category cards (free tier).
String shortScorePhrase(int score) {
  if (score >= 85) return 'روزِ درخشان';
  if (score >= 70) return 'رو به رشد';
  if (score >= 55) return 'متعادل و آرام';
  if (score >= 40) return 'نیازمند کمی حوصله';
  return 'روزِ مراقبت از خود';
}
