import '../../data/content/fortunes_content.dart';
import '../../data/content/traditions_content.dart';
import '../horoscope/deterministic_random.dart';

/// Pure calculators for the fortune modules (no Flutter dependencies).
///
/// Everything is derived offline from data the user already entered
/// (name + Jalali birth date); daily draws are seeded with the day key so
/// they stay stable for the whole day, like the horoscope engines.

// ── Gem Oracle ─────────────────────────────────────────────────────────

class GemOracle {
  GemOracle._();

  /// Birthstone by Jalali birth month (1..12).
  static Map<String, Object?> birthstoneFor(int jalaliMonth) =>
      FortunesContent.gemStones[(jalaliMonth - 1).clamp(0, 11)];

  /// Three distinct stones for today's reading (love / career / health),
  /// deterministic per [name] + [dayKey].
  static List<Map<String, Object?>> dailyDraw(String name, String dayKey) {
    final rng = DetRandom(fnv1a32('gem|$name|$dayKey'));
    final pool = List<Map<String, Object?>>.from(FortunesContent.gemStones);
    return [rng.take(pool), rng.take(pool), rng.take(pool)];
  }
}

// ── Abjad Fortune ──────────────────────────────────────────────────────

class AbjadFortune {
  AbjadFortune._();

  /// Abjad value of a name/phrase using the shared letter table.
  static int valueOf(String text) {
    var sum = 0;
    for (final rune in text.runes) {
      sum += TraditionsContent.abjadValues[String.fromCharCode(rune)] ?? 0;
    }
    return sum;
  }

  /// Traditional reading: abjad of the name + the mother's name, with a
  /// daily seed so the same niyat can be re-read next day.
  static String fortuneFor({
    required String name,
    required String motherName,
    required String dayKey,
  }) {
    final rng = DetRandom(
      fnv1a32('abjadfal|$name|$motherName|$dayKey'),
    );
    return rng.pick(FortunesContent.abjadFortunes);
  }
}

// ── Greek (Hellenistic) ────────────────────────────────────────────────

class GreekAstrology {
  GreekAstrology._();

  /// Hellenistic profile for a Western sign id ('aries' … 'pisces').
  static Map<String, Object?> forSignId(String id) =>
      FortunesContent.greekSigns.firstWhere(
        (s) => s['id'] == id,
        orElse: () => FortunesContent.greekSigns.first,
      );
}

// ── Marriage ───────────────────────────────────────────────────────────

class MarriageAstrology {
  MarriageAstrology._();

  /// Marriage profile for a Western sign id.
  static Map<String, Object?> forSignId(String id) =>
      FortunesContent.marriageSigns.firstWhere(
        (s) => s['id'] == id,
        orElse: () => FortunesContent.marriageSigns.first,
      );
}

// ── Birth-month traits ─────────────────────────────────────────────────

class MonthTraits {
  MonthTraits._();

  /// Traits text by Jalali month (1..12).
  static Map<String, Object?> forMonth(int jalaliMonth) =>
      FortunesContent.monthTraits[(jalaliMonth - 1).clamp(0, 11)];
}

// ── Tarot ──────────────────────────────────────────────────────────────

class Tarot {
  Tarot._();

  static int _digitSum(int n) {
    var v = n;
    var sum = 0;
    while (v > 0) {
      sum += v % 10;
      v ~/= 10;
    }
    return sum;
  }

  /// Birth Major Arcana: sum of all digits of the (Gregorian) birth date;
  /// while the sum exceeds 22, sum its digits again; 22 maps to The Fool.
  static int birthCard(DateTime gregorian) {
    var s = _digitSum(gregorian.year) +
        _digitSum(gregorian.month) +
        _digitSum(gregorian.day);
    while (s > 22) {
      s = _digitSum(s);
    }
    return s == 22 ? 0 : s;
  }

  static Map<String, Object?> card(int index) =>
      FortunesContent.tarotCards[index.clamp(0, 21)];

  /// Card of the day for a sign, deterministic per [dayKey].
  static Map<String, Object?> dailyCard(String signId, String dayKey) {
    final rng = DetRandom(fnv1a32('tarot|$signId|$dayKey'));
    return card(rng.nextInt(22));
  }
}

// ── Inner animal ───────────────────────────────────────────────────────

class SpiritAnimal {
  SpiritAnimal._();

  /// Spirit animal for a Western sign id.
  static Map<String, Object?> forSignId(String id) =>
      FortunesContent.spiritAnimals.firstWhere(
        (a) => a['id'] == id,
        orElse: () => FortunesContent.spiritAnimals.first,
      );
}
