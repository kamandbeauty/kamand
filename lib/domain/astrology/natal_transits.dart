import 'natal_chart.dart';
import 'natal_engine.dart';

/// A planet's position in the sky right now, linked back to the natal chart.
class TransitInfo {
  const TransitInfo({
    required this.body,
    required this.signId,
    required this.degreeInSign,
    required this.isRetrograde,
    required this.natalLink,
  });

  /// Transit body id ('sun' … 'neptune').
  final String body;

  /// Tropical sign the body is currently in.
  final String signId;

  /// Degree inside that sign (0–30).
  final double degreeInSign;

  final bool isRetrograde;

  /// How this transit touches the *birth* chart — one of:
  ///  ''                        — no special link
  ///  'conjunct:<body>'         — within ~6° of a natal planet
  ///  'house:<n>'               — passing through natal house n (1–12)
  ///  'sun-sign'                — in the natal Sun's own sign
  final String natalLink;

  bool get hasLink => natalLink.isNotEmpty;
}

/// Live sky vs. birth chart — the "Transits" section of the reference
/// mockup. Purely offline: everything is recomputed from the same validated
/// engine that draws the natal wheel, for *now* (or any moment).
class NatalTransits {
  NatalTransits._();

  /// Conjunction orb (degrees) for a transit→natal-planet link.
  static const double _conjunctOrb = 6.0;

  /// Current sky for [utcNow] linked against [natal].
  ///
  /// Houses are used only when the natal chart has them (birth time known);
  /// otherwise the fallback link is the natal Sun's sign.
  static List<TransitInfo> compute(NatalChart natal, DateTime utcNow) {
    final sky = NatalEngine.compute(utcNow, withHouses: false);
    final natalByBody = {
      for (final p in natal.planetPositions) p.body: p
    };
    final natalSun = natalByBody['sun'];

    return [
      for (final pos in sky.planetPositions)
        TransitInfo(
          body: pos.body,
          signId: pos.signId,
          degreeInSign: pos.longitudeDegrees % 30.0,
          isRetrograde: pos.isRetrograde,
          natalLink:
              _linkOf(pos, natalByBody, natal.houses, natalSun?.signId),
        ),
    ];
  }

  static String _linkOf(
    PlanetPosition pos,
    Map<String, PlanetPosition> natalByBody,
    List<House> houses,
    String? natalSunSign,
  ) {
    // 1) Tightest link: a conjunction with a natal planet.
    PlanetPosition? conjunct;
    double bestOrb = _conjunctOrb;
    for (final natal in natalByBody.values) {
      var orb = (pos.longitudeDegrees - natal.longitudeDegrees).abs();
      if (orb > 180) orb = 360 - orb;
      if (orb <= bestOrb) {
        bestOrb = orb;
        conjunct = natal;
      }
    }
    if (conjunct != null) return 'conjunct:${conjunct.body}';

    // 2) Which natal house the transit is passing through.
    if (houses.isNotEmpty) {
      for (var k = 0; k < 12; k++) {
        final start = houses[k].cuspDegrees;
        final end = houses[(k + 1) % 12].cuspDegrees;
        if (_inArc(pos.longitudeDegrees, start, end)) {
          return 'house:${k + 1}';
        }
      }
    }

    // 3) Fallback: transiting the natal Sun's own sign.
    if (natalSunSign != null && pos.signId == natalSunSign) return 'sun-sign';
    return '';
  }

  static bool _inArc(double lon, double start, double end) {
    if (start <= end) return lon >= start && lon < end;
    return lon >= start || lon < end; // arc wraps 0°
  }
}
