import '../../data/content/traditions_content.dart';
import 'sky_math.dart';

/// One day of the Maya sacred round (Tzolkin): a tone (1–13) paired with a
/// nawal (day sign, 0 = Imix … 19 = Ajaw) — 260 unique combinations.
class TzolkinDay {
  const TzolkinDay({required this.tone, required this.nawalIndex});

  final int tone;
  final int nawalIndex;

  Map<String, Object?> get nawal => TraditionsContent.mayanNawals[nawalIndex];
}

/// Tzolkin arithmetic on the standard GMT correlation.
///
/// Anchor: 13.0.0.0.0 of the Long Count — 21 Dec 2012 (JDN 2456283) — was
/// 4 Ajaw; tones cycle every 13 days, nawals every 20.
class TzolkinCalculator {
  TzolkinCalculator._();

  static int _mod(int v, int m) => ((v % m) + m) % m;

  static TzolkinDay forDate(DateTime utc) {
    final jdn = SkyMath.julianDayNumber(utc);
    return TzolkinDay(
      tone: _mod(jdn - 2456280, 13) + 1,
      nawalIndex: _mod(jdn - 2456264, 20),
    );
  }
}
