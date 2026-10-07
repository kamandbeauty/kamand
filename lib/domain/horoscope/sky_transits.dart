import '../../data/content/astro_content.dart';
import '../traditions/sky_math.dart';

/// Astronomy-driven "sky of the day/week/month" — the classical
/// sun-sign-column technique, computed live from the validated Meeus
/// series (see SkyMath):
///
/// * the Moon's tropical sign (changes every ~2.5 days),
/// * the Moon phase bucket from the Sun–Moon elongation,
/// * the Moon's Ptolemaic aspect *by sign distance* to the natal Sun
///   (conjunction / sextile / square / trine / opposition),
/// * the Chaldean weekday ruler (Saturday = Saturn … Friday = Venus).
///
/// Pure functions, no Flutter dependencies; texts come from the
/// generated AstroContent bank.
class SkyTransits {
  SkyTransits._();

  /// Moon's tropical sign index, 0..11 (aries..pisces).
  static int moonSignIndex(DateTime utc) {
    final lon = SkyMath.moonLongitude(SkyMath.julianDay(utc));
    return (lon ~/ 30) % 12;
  }

  /// Sun's tropical sign index, 0..11 (aries..pisces).
  static int sunSignIndex(DateTime utc) {
    final lon = SkyMath.sunLongitude(SkyMath.julianDay(utc));
    return (lon ~/ 30) % 12;
  }

  /// Moon phase bucket 0..7 (0 = new … 4 = full … 7 = waning crescent),
  /// from the elongation (Moon − Sun) in 45° steps.
  static int moonPhase(DateTime utc) {
    final jd = SkyMath.julianDay(utc);
    final elong =
        (SkyMath.moonLongitude(jd) - SkyMath.sunLongitude(jd)) % 360.0;
    final bucket = (elong / 45).floor();
    return bucket.clamp(0, 7);
  }

  /// Index into AstroContent.aspects for the Moon's aspect (by sign
  /// distance) to [sunSignIndex]: 0 conjunction, 1 sextile, 2 square,
  /// 3 trine, 4 opposition, 5 none.
  static int aspectToSun(int moonSign, int natalSunSign) {
    final d = (moonSign - natalSunSign + 12) % 12;
    switch (d) {
      case 0:
        return 0; // conjunction
      case 2:
        return 1; // sextile
      case 3:
        return 2; // square
      case 4:
        return 3; // trine
      case 6:
        return 4; // opposition
      default:
        return 5; // none
    }
  }

  /// Element id of a sign index: fire/earth/air/water.
  static String elementOf(int signIndex) =>
      const ['fire', 'earth', 'air', 'water'][signIndex % 4];

  /// Chaldean weekday ruler, index 0..6 = Saturday..Friday.
  static int weekdayRulerIndex(DateTime utc) {
    switch (utc.weekday) {
      case DateTime.saturday:
        return 0; // Saturn
      case DateTime.sunday:
        return 1; // Sun
      case DateTime.monday:
        return 2; // Moon
      case DateTime.tuesday:
        return 3; // Mars
      case DateTime.wednesday:
        return 4; // Mercury
      case DateTime.thursday:
        return 5; // Jupiter
      default:
        return 6; // Venus (Friday)
    }
  }

  // ── Text accessors ────────────────────────────────────────────────

  static Map<String, Object?> moonInSign(int index) =>
      AstroContent.moonInSigns[index.clamp(0, 11)];

  static Map<String, Object?> moonPhaseInfo(int bucket) =>
      AstroContent.moonPhases[bucket.clamp(0, 7)];

  static Map<String, Object?> aspect(int aspectIndex) =>
      AstroContent.aspects[aspectIndex.clamp(0, 5)];

  static Map<String, Object?> weekdayRuler(int index) =>
      AstroContent.weekdayRulers[index.clamp(0, 6)];

  /// Deterministic weekly-theme pick for [weekStart] (a Saturday).
  static String weeklyTheme(DateTime weekStartUtc) {
    final element = elementOf(moonSignIndex(weekStartUtc));
    final variants = AstroContent.weekThemes[element]!;
    // Stable pick from the week's Julian-day number.
    final jdn = SkyMath.julianDayNumber(weekStartUtc);
    return variants[jdn % variants.length];
  }

  /// Seasonal sky map for a Solar-Hijri month (1..12).
  static Map<String, Object?> monthSeason(int jalaliMonth) =>
      AstroContent.monthSeasons[(jalaliMonth - 1).clamp(0, 11)];
}
