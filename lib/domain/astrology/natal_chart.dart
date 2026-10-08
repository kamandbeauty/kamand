/// Birth-chart domain models (product spec §46 — v2 feature).
///
/// v1 stores the birth data (date/time/city) and renders a locked
/// "coming soon" section; these models define the contract the future
/// astronomy engine will fill. Pure data classes — no Flutter deps.

/// A computed natal chart for a birth moment.
class NatalChart {
  const NatalChart({
    required this.planetPositions,
    required this.houses,
    required this.aspects,
    required this.ascendant,
  });

  /// Ecliptic longitudes of the classical bodies (Sun..Pluto + nodes).
  final List<PlanetPosition> planetPositions;

  /// The twelve houses with their cusp degrees.
  final List<House> houses;

  /// Major aspects found between the positions.
  final List<Aspect> aspects;

  /// The rising sign + degree — null when the birth time or place is
  /// unknown (an ascendant needs both).
  final Ascendant? ascendant;
}

/// Position of one body on the ecliptic (degrees, 0–360).
class PlanetPosition {
  const PlanetPosition({
    required this.body,
    required this.longitudeDegrees,
    required this.signId,
    required this.isRetrograde,
  });

  /// e.g. 'sun', 'moon', 'mercury', …
  final String body;
  final double longitudeDegrees;

  /// Zodiac id the longitude falls in.
  final String signId;
  final bool isRetrograde;
}

/// One of the twelve astrological houses.
class House {
  const House({
    required this.index,
    required this.cuspDegrees,
    required this.signId,
  });

  /// 1–12.
  final int index;
  final double cuspDegrees;
  final String signId;
}

/// A major aspect between two bodies (conjunction, trine, …).
class Aspect {
  const Aspect({
    required this.bodyA,
    required this.bodyB,
    required this.kind,
    required this.orbDegrees,
  });

  final String bodyA;
  final String bodyB;

  /// 'conjunction', 'sextile', 'square', 'trine', 'opposition'.
  final String kind;
  final double orbDegrees;
}

/// The ascendant (rising sign) — needs an accurate birth time + place.
class Ascendant {
  const Ascendant({
    required this.signId,
    required this.longitudeDegrees,
    required this.midheavenDegrees,
  });

  final String signId;

  /// Full ecliptic longitude of the rising point (0–360).
  final double longitudeDegrees;

  /// Midheaven (MC) ecliptic longitude — the culminating point.
  final double midheavenDegrees;

  /// Degree within the rising sign (0–30).
  double get degreeInSign => longitudeDegrees % 30.0;
}
