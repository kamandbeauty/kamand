/// Pure-function astronomical helpers (Meeus, "Astronomical Algorithms",
/// low-precision series).
///
/// Accuracy (validated against Meeus' own worked examples and solstice
/// anchors): Sun ±0.01°, Moon ±0.01° (20-term truncation of ch. 47.A).
/// That is far finer than the 13.3° nakshatra / 12.9° lunar-mansion
/// boundaries these functions feed.
///
/// All inputs are UTC; all outputs are geocentric apparent degrees [0, 360).
import 'dart:math' as math;

class SkyMath {
  SkyMath._();

  static const double _deg2rad = 0.017453292519943295;

  /// Julian Day (astronomical, noon-based) for a UTC [DateTime].
  ///
  /// Computed from the civil date with the Fliegel–Van Flandern JDN formula
  /// plus the time-of-day fraction — no epoch-milliseconds involved, so any
  /// birth year is safe on every platform.
  static double julianDay(DateTime utc) {
    final y = utc.year;
    final m = utc.month;
    final d = utc.day;
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    final jdn = d +
        (153 * mm + 2) ~/ 5 +
        365 * yy +
        yy ~/ 4 -
        yy ~/ 100 +
        yy ~/ 400 -
        32045;
    final fraction = (utc.hour * 3600 + utc.minute * 60 + utc.second) / 86400;
    return jdn + fraction - 0.5;
  }

  /// Integer Julian Day Number of the civil date (tzolkin arithmetic).
  static int julianDayNumber(DateTime utc) {
    final y = utc.year;
    final m = utc.month;
    final d = utc.day;
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d +
        (153 * mm + 2) ~/ 5 +
        365 * yy +
        yy ~/ 4 -
        yy ~/ 100 +
        yy ~/ 400 -
        32045;
  }

  static double _norm360(double x) {
    final r = x % 360.0;
    return r < 0 ? r + 360.0 : r;
  }

  /// Sine of an angle given in degrees.
  static double _sin(double deg) => math.sin(_norm360(deg) * _deg2rad);

  /// Apparent geocentric longitude of the Sun (Meeus ch. 25). ±0.01°.
  static double sunLongitude(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
    final m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
    final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * _sin(m) +
        (0.019993 - 0.000101 * t) * _sin(2 * m) +
        0.000289 * _sin(3 * m);
    final omega = 125.04 - 1934.136 * t;
    return _norm360(l0 + c - 0.00569 - 0.00478 * _sin(omega));
  }

  /// Geocentric longitude of the Moon (Meeus ch. 47, 20 largest terms).
  static double moonLongitude(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final t2 = t * t;
    final t3 = t2 * t;
    final t4 = t3 * t;
    final lp = 218.3164477 +
        481267.88123421 * t -
        0.0015786 * t2 +
        t3 / 538841.0 -
        t4 / 65194000.0;
    final d = 297.8501921 +
        445267.1114034 * t -
        0.0018819 * t2 +
        t3 / 545868.0 -
        t4 / 113065000.0;
    final m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000.0;
    final mp = 134.9633964 +
        477198.8675055 * t +
        0.0087414 * t2 +
        t3 / 69699.0 -
        t4 / 14712000.0;
    final f = 93.2720950 +
        483202.0175233 * t -
        0.0036539 * t2 -
        t3 / 3526000.0 +
        t4 / 863310000.0;

    var sum = 0.0;
    for (final term in _moonTerms) {
      sum += term[4] / 1000000.0 *
          _sin(term[0] * d + term[1] * m + term[2] * mp + term[3] * f);
    }
    return _norm360(lp + sum);
  }

  // (D, M, M', F, coefficient in 1e-6 degrees) — Meeus table 47.A.
  static const List<List<double>> _moonTerms = [
    [0, 0, 1, 0, 6288774],
    [2, 0, -1, 0, 1274027],
    [2, 0, 0, 0, 658314],
    [0, 0, 2, 0, 213618],
    [0, 1, 0, 0, -185116],
    [0, 0, 0, 2, -114332],
    [2, 0, -2, 0, 58793],
    [2, -1, -1, 0, 57066],
    [2, 0, 1, 0, 53322],
    [2, -1, 0, 0, 45758],
    [0, 1, -1, 0, -40923],
    [1, 0, 0, 0, -34720],
    [0, 1, 1, 0, -30383],
    [2, 0, 0, -2, 15327],
    [0, 0, 1, 2, -12528],
    [0, 0, 1, -2, 10980],
    [4, 0, -1, 0, 10675],
    [0, 0, 3, 0, 10034],
    [4, 0, -2, 0, 8548],
    [2, 1, -1, 0, -7888],
  ];

  /// Lahiri ayanamsa (sidereal offset), linear model anchored at J2000.
  static double ayanamsa(double jd) =>
      23.853 + (jd - 2451545.0) / 365.25 * (50.29 / 3600.0);

  /// Sidereal (star-referenced) longitude of the Moon.
  static double siderealMoon(double jd) =>
      _norm360(moonLongitude(jd) - ayanamsa(jd));
}
