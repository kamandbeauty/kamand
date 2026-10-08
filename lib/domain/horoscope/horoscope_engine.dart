import 'package:shamsi_date/shamsi_date.dart';
import '../../core/date/app_date.dart';

import '../zodiac/zodiac_repository.dart';
import '../zodiac/zodiac_sign.dart';
import 'deterministic_random.dart';
import 'horoscope_models.dart';

/// Bump when generation logic changes → cached rows regenerate.
const int kHoroscopeGeneratedVersion = 2;

/// The deterministic horoscope generator.
///
/// Pipeline: profile → zodiac → current Solar-Hijri date → daily seed →
/// horoscope. Two users with the same sign get the same base content for a
/// given day; personalization (score jitter, lucky details) is a thin,
/// reversible layer computed on top (see [personalJitter]).
class HoroscopeEngine {
  const HoroscopeEngine(this._zodiacRepository);

  final ZodiacRepository _zodiacRepository;

  // ── Seeds ─────────────────────────────────────────────────────────

  /// hash(zodiacId + solar year + month + day) — the canonical daily seed.
  static int dailySeed(String zodiacId, int year, int month, int day) =>
      fnv1a32('$zodiacId|$year-$month-$day');

  static int weeklySeed(String zodiacId, Jalali weekStart) =>
      fnv1a32('week|$zodiacId|${weekStart.year}-${weekStart.month}-${weekStart.day}');

  static int monthlySeed(String zodiacId, int year, int month) =>
      fnv1a32('month|$zodiacId|$year-$month');

  // ── Daily ─────────────────────────────────────────────────────────

  /// Generates the deterministic daily horoscope for a sign and date.
  DailyHoroscope generateDaily(ZodiacSign sign, Jalali date) {
    final y = date.year, m = date.month, d = date.day;
    final index = _signIndex(sign);

    final scoreRng = DetRandom(fnv1a32('scores|${sign.id}|$y-$m-$d'));
    final love = _score(scoreRng, index, 0);
    final career = _score(scoreRng, index, 1);
    final finance = _score(scoreRng, index, 2);
    final mood = _score(scoreRng, index, 3);
    final energy = _score(scoreRng, index, 4);

    final textRng = DetRandom(fnv1a32('text|${sign.id}|$y-$m-$d'));
    final generalText = textRng.pick(sign.dailyGeneral);
    final loveText = textRng.pick(sign.dailyLove);
    final careerText = textRng.pick(sign.dailyCareer);
    final financeText = textRng.pick(sign.dailyFinance);
    final moodText = textRng.pick(sign.dailyMood);
    final warningText = textRng.pick(sign.dailyWarning);
    final opportunityText = textRng.pick(sign.dailyOpportunity);

    final luckyRng = DetRandom(fnv1a32('lucky|${sign.id}|$y-$m-$d'));
    final lucky = LuckyInfo(
      color: luckyRng.pick(sign.luckyColors),
      number: luckyRng.pick(sign.luckyNumbers),
      time: luckyRng.pick(sign.luckyTimes),
    );

    return DailyHoroscope(
      zodiacId: sign.id,
      date: '${y}-${_two(m)}-${_two(d)}',
      scores: DailyScores(
        love: love,
        career: career,
        finance: finance,
        mood: mood,
        energy: energy,
      ),
      lucky: lucky,
      generalText: generalText,
      loveText: loveText,
      careerText: careerText,
      financeText: financeText,
      moodText: moodText,
      warningText: warningText,
      opportunityText: opportunityText,
      generatedVersion: kHoroscopeGeneratedVersion,
    );
  }

  /// Convenience: by sign id.
  DailyHoroscope generateDailyById(String zodiacId, Jalali date) =>
      generateDaily(_zodiacRepository.byIdOrFail(zodiacId), date);

  /// Personal, deterministic ±3 jitter layered on a base score
  /// (same sign+date+profile → same result; different profiles diverge).
  static int personalJitter(
      String profileId, String zodiacId, String dayKey, int baseScore) {
    final j = fnv1a32('jitter|$profileId|$zodiacId|$dayKey') % 7 - 3;
    return clampInt(baseScore + j, 0, 100);
  }

  // ── Weekly ────────────────────────────────────────────────────────

  WeeklyHoroscope generateWeekly(ZodiacSign sign, Jalali weekStart) {
    final days = <WeeklyDay>[];
    for (var i = 0; i < 7; i++) {
      final date = AppDate.addDays(weekStart, i);
      final daily = generateDaily(sign, date);
      days.add(WeeklyDay(date: date, scores: daily.scores));
    }
    final summary =
        DetRandom(weeklySeed(sign.id, weekStart)).pick(sign.weeklySummaries);
    return WeeklyHoroscope(
      zodiacId: sign.id,
      weekStart: weekStart,
      days: days,
      summaryText: summary,
    );
  }

  WeeklyHoroscope generateWeeklyById(String zodiacId, Jalali weekStart) =>
      generateWeekly(_zodiacRepository.byIdOrFail(zodiacId), weekStart);

  // ── Monthly ───────────────────────────────────────────────────────

  MonthlyHoroscope generateMonthly(ZodiacSign sign, int year, int month) {
    final index = _signIndex(sign);
    final scoreRng =
        DetRandom(fnv1a32('mscores|${sign.id}|$year-$month'));
    final love = _score(scoreRng, index, 0);
    final career = _score(scoreRng, index, 1);
    final finance = _score(scoreRng, index, 2);
    final mood = _score(scoreRng, index, 3);
    final energy = _score(scoreRng, index, 4);

    final textRng = DetRandom(monthlySeed(sign.id, year, month));
    return MonthlyHoroscope(
      zodiacId: sign.id,
      year: year,
      month: month,
      scores: DailyScores(
        love: love,
        career: career,
        finance: finance,
        mood: mood,
        energy: energy,
      ),
      focusText: textRng.pick(sign.monthlyFocus),
      loveText: textRng.pick(sign.monthlyLove),
      careerText: textRng.pick(sign.monthlyCareer),
      financeText: textRng.pick(sign.monthlyFinance),
      energyText: textRng.pick(sign.monthlyEnergy),
      opportunityText: textRng.pick(sign.monthlyOpportunity),
      warningText: textRng.pick(sign.monthlyWarning),
    );
  }

  MonthlyHoroscope generateMonthlyById(String zodiacId, int year, int month) =>
      generateMonthly(_zodiacRepository.byIdOrFail(zodiacId), year, month);

  // ── internals ─────────────────────────────────────────────────────

  int _signIndex(ZodiacSign sign) {
    final all = _zodiacRepository.allSigns();
    for (var i = 0; i < all.length; i++) {
      if (all[i].id == sign.id) return i;
    }
    return 0;
  }

  /// base 42..91 + sign/category bias (−5..+5) → clamp 25..97.
  static int _score(DetRandom rng, int signIndex, int categoryIndex) {
    final bias = (signIndex * 7 + categoryIndex * 5) % 11 - 5;
    return clampInt(42 + rng.nextInt(50) + bias, 25, 97);
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
