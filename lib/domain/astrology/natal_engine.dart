import 'dart:math' as math;

import '../../core/constants/cities.dart';
import '../traditions/sky_math.dart';
import 'natal_chart.dart';

/// Offline natal-chart engine — fills the [NatalChart] contract with real
/// astronomy:
///
/// * Sun & Moon: the validated Meeus series from [SkyMath] (±0.01°/±0.3°).
/// * Mercury..Saturn: JPL's "Keplerian elements for approximate positions"
///   (Standish; elements + per-century rates, Table 2a + the extra M-terms
///   of Table 2b for Jupiter/Saturn), converted to geocentric ecliptic
///   longitude of date (general precession applied). Accuracy ~0.1–0.2° —
///   far beyond what sign placement needs.
/// * Retrogrades: sign of the daily longitudinal motion.
/// * Ascendant & midheaven: local sidereal time + obliquity + geographic
///   latitude; houses: equal-house from the ascendant (method note shown
///   in the UI).
///
/// Pure static functions, no Flutter dependencies.
class NatalEngine {
  NatalEngine._();

  static const _deg2rad = math.pi / 180.0;

  /// Classical bodies shown in the chart (in traditional order).
  static const List<String> bodies = [
    'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn',
  ];

  static const Map<String, String> bodyNamesFa = {
    'sun': 'خورشید',
    'moon': 'ماه',
    'mercury': 'عطارد',
    'venus': 'زهره',
    'mars': 'مریخ',
    'jupiter': 'مشتری',
    'saturn': 'زحل',
  };

  static const List<String> _signIds = [
    'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
    'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces',
  ];

  /// Computes the full chart for a birth moment (UTC) and optional
  /// geographic coordinates. Without coordinates (or [withHouses] false)
  /// the ascendant/houses are omitted but planets & aspects still work.
  static NatalChart compute(
    DateTime utcBirth, {
    double? latitude,
    double? longitude,
    bool withHouses = true,
  }) {
    final jd = SkyMath.julianDay(utcBirth);
    final positions = <PlanetPosition>[
      _position('sun', SkyMath.sunLongitude(jd), jd),
      _position('moon', SkyMath.moonLongitude(jd), jd),
      for (final b in ['mercury', 'venus', 'mars', 'jupiter', 'saturn'])
        _position(b, _geocentricLongitude(b, jd), jd),
    ];

    final aspects = _aspectsBetween(positions);

    Ascendant? ascendant;
    var houses = <House>[];
    if (withHouses && latitude != null && longitude != null) {
      ascendant = _ascendant(jd, latitude, longitude);
      houses = [
        for (var k = 0; k < 12; k++)
          House(
            index: k + 1,
            cuspDegrees: _norm360(ascendant.longitudeDegrees + 30.0 * k),
            signId: _signIds[(_norm360(ascendant.longitudeDegrees + 30.0 * k)
                        .floor() ~/
                    30) %
                12],
          ),
      ];
    }

    return NatalChart(
      planetPositions: positions,
      houses: houses,
      aspects: aspects,
      ascendant: ascendant,
    );
  }

  /// Geocentric tropical longitude of [body] ('mercury'…'saturn'; also
  /// 'earth' gives the heliocentric Earth direction) at [jd].
  static double _geocentricLongitude(String body, double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final (px, py) = _heliocentricXY(body, jd);
    final (ex, ey) = _heliocentricXY('earth', jd);
    final lon = math.atan2(py - ey, px - ex) / _deg2rad;
    return _norm360(lon + _precession(t));
  }

  /// Sun's geocentric longitude from the Earth's own elements — an
  /// independent cross-check against [SkyMath.sunLongitude].
  static double sunFromEarthElements(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final (ex, ey) = _heliocentricXY('earth', jd);
    return _norm360(
        math.atan2(-ey, -ex) / _deg2rad + _precession(t));
  }

  /// General precession in longitude from J2000 to date (degrees).
  static double _precession(double t) =>
      (5029.0966 * t + 1.11113 * t * t) / 3600.0;

  // ── JPL Keplerian elements (Standish, Table 2a; epoch J2000) ──────
  // rows: [a, e, i, L, longPeri, longNode] + per-century rates.
  static const Map<String, List<List<double>>> _elements = {
    'mercury': [
      [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593],
      [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081],
    ],
    'venus': [
      [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255],
      [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418],
    ],
    'earth': [
      [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0],
      [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0],
    ],
    'mars': [
      [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891],
      [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343],
    ],
    'jupiter': [
      [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909],
      [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106],
    ],
    'saturn': [
      [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448],
      [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794],
    ],
  };

  /// Extra M-terms for Jupiter/Saturn (JPL Table 2b): b, c, s, f.
  static const Map<String, List<double>> _mTerms = {
    'jupiter': [-0.00012452, 0.06064060, -0.35635438, 38.35125000],
    'saturn': [0.00025899, -0.13434469, 0.87320147, 38.35125000],
  };

  /// Heliocentric ecliptic x/y (AU) of a body at [jd] (J2000 frame).
  static (double, double) _heliocentricXY(String body, double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final el = _elements[body]!;
    final a = el[0][0] + el[1][0] * t;
    final e = el[0][1] + el[1][1] * t;
    final i = (el[0][2] + el[1][2] * t) * _deg2rad;
    final l = el[0][3] + el[1][3] * t;
    final w = el[0][4] + el[1][4] * t;
    final o = el[0][5] + el[1][5] * t;

    var m = _norm360(l - w);
    final mt = _mTerms[body];
    if (mt != null) {
      m = m +
          mt[0] * t * t +
          mt[1] * math.cos(mt[3] * t * _deg2rad) +
          mt[2] * math.sin(mt[3] * t * _deg2rad);
    }
    if (m > 180) m -= 360;
    final mr = m * _deg2rad;

    // Kepler equation (Newton).
    var ecc = mr;
    for (var k = 0; k < 12; k++) {
      ecc -= (ecc - e * math.sin(ecc) - mr) / (1 - e * math.cos(ecc));
    }
    final nu = 2 *
        math.atan2(math.sqrt(1 + e) * math.sin(ecc / 2),
            math.sqrt(1 - e) * math.cos(ecc / 2));
    final r = a * (1 - e * math.cos(ecc));

    final u = nu + (w - o) * _deg2rad;
    final orad = o * _deg2rad;
    final x = r * (math.cos(orad) * math.cos(u) - math.sin(orad) * math.sin(u) * math.cos(i));
    final y = r * (math.sin(orad) * math.cos(u) + math.cos(orad) * math.sin(u) * math.cos(i));
    return (x, y);
  }

  static PlanetPosition _position(String body, double longitude, double jd) {
    final signIdx = (longitude.floor() ~/ 30) % 12;
    return PlanetPosition(
      body: body,
      longitudeDegrees: longitude,
      signId: _signIds[signIdx],
      isRetrograde: _isRetrograde(body, longitude, jd),
    );
  }

  /// Retrograde when the longitude decreases over ±0.5 day.
  static bool _isRetrograde(String body, double current, double jd) {
    if (body == 'sun' || body == 'moon') return false;
    final before = _geocentricLongitude(body, jd - 0.5);
    final after = _geocentricLongitude(body, jd + 0.5);
    var d = after - before;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d < 0;
  }

  // ── Aspects (Ptolemaic, with classical orbs) ──────────────────────
  static const Map<String, double> _aspectAngles = {
    'conjunction': 0,
    'sextile': 60,
    'square': 90,
    'trine': 120,
    'opposition': 180,
  };
  static const Map<String, double> _aspectOrbs = {
    'conjunction': 8,
    'sextile': 4,
    'square': 6,
    'trine': 7,
    'opposition': 8,
  };

  static List<Aspect> _aspectsBetween(List<PlanetPosition> positions) {
    final found = <Aspect>[];
    for (var a = 0; a < positions.length; a++) {
      for (var b = a + 1; b < positions.length; b++) {
        var diff =
            (positions[a].longitudeDegrees - positions[b].longitudeDegrees)
                .abs();
        if (diff > 180) diff = 360 - diff;
        for (final entry in _aspectAngles.entries) {
          final orb = (diff - entry.value).abs();
          if (orb <= _aspectOrbs[entry.key]!) {
            found.add(Aspect(
              bodyA: positions[a].body,
              bodyB: positions[b].body,
              kind: entry.key,
              orbDegrees: orb,
            ));
            break;
          }
        }
      }
    }
    found.sort((x, y) => x.orbDegrees.compareTo(y.orbDegrees));
    return found;
  }

  // ── Ascendant & houses ────────────────────────────────────────────

  /// Greenwich mean sidereal time in degrees (Meeus 12.4).
  static double _gmst(double jd) {
    final d = jd - 2451545.0;
    final t = d / 36525.0;
    return _norm360(280.46061837 +
        360.98564736629 * d +
        0.000387933 * t * t -
        t * t * t / 38710000.0);
  }

  /// Obliquity of the ecliptic (degrees, simplified).
  static double _obliquity(double jd) =>
      23.4392911 - 0.0130042 * ((jd - 2451545.0) / 36525.0);

  /// Ascendant (rising point of the ecliptic) for a place & moment.
  static Ascendant _ascendant(double jd, double latitude, double longitude) {
    final ramc = _norm360(_gmst(jd) + longitude); // local sidereal time
    final eps = _obliquity(jd) * _deg2rad;
    final lat = latitude * _deg2rad;

    final asc = _norm360(math.atan2(
            math.cos(ramc * _deg2rad),
            -(math.sin(ramc * _deg2rad) * math.cos(eps) +
                math.tan(lat) * math.sin(eps))) /
        _deg2rad);

    final mc = _norm360(math.atan2(
            math.sin(ramc * _deg2rad),
            math.cos(ramc * _deg2rad) * math.cos(eps)) /
        _deg2rad);

    final signIdx = (asc.floor() ~/ 30) % 12;
    return Ascendant(
      signId: _signIds[signIdx],
      longitudeDegrees: asc,
      midheavenDegrees: mc,
    );
  }

  static double _norm360(double x) {
    final r = x % 360.0;
    return r < 0 ? r + 360.0 : r;
  }

  // ── Birth-moment helpers ──────────────────────────────────────────

  /// Converts a Jalali birth date + local Iranian clock time ("08:30",
  /// null → noon) into UTC, using the historical standard offset
  /// (+3:30) and the 1978–2021 daylight-saving approximation (+4:30
  /// from ~21 March to ~21 September).
  static DateTime jalaliBirthToUtc(
    int jy,
    int jm,
    int jd,
    String? time,
  ) {
    final g = _jalaliToGregorian(jy, jm, jd);
    var hour = 12;
    var minute = 0;
    if (time != null) {
      final parts = time.split(':');
      final h = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
      final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (h != null && h >= 0 && h <= 23 && m != null && m >= 0 && m <= 59) {
        hour = h;
        minute = m;
      }
    }
    final local = DateTime.utc(g[0], g[1], g[2], hour, minute);
    var offsetMinutes = 210; // +3:30
    final summer = (g[1] > 3 && g[1] < 9) ||
        (g[1] == 3 && g[2] >= 21) ||
        (g[1] == 9 && g[2] <= 21);
    if (g[0] >= 1978 && g[0] <= 2021 && summer) offsetMinutes = 270;
    return local.subtract(Duration(minutes: offsetMinutes)).toUtc();
  }

  /// Jalali → Gregorian (no package dependency; the standard algorithm).
  static List<int> _jalaliToGregorian(int jy, int jm, int jd) {
    final jdn = _jalaliToJdn(jy, jm, jd);
    // Gregorian from JDN (Fliegel–Van Flandern).
    final l = jdn + 68569;
    final n = (4 * l) ~/ 146097;
    var ll = l - (146097 * n + 3) ~/ 4;
    final i = (4000 * (ll + 1)) ~/ 1461001;
    ll = ll - (1461 * i) ~/ 4 + 31;
    final j = (80 * ll) ~/ 2447;
    final day = ll - (2447 * j) ~/ 80;
    ll = j ~/ 11;
    final month = j + 2 - 12 * ll;
    final year = 100 * (n - 49) + i + ll;
    return [year, month, day];
  }

  /// Jalali leap year? In the modern era (1178–1633 AP) the astronomical
  /// calendar follows a 33-year cycle; leap residues: 1, 5, 9, 13, 17, 22,
  /// 26, 30. Verified against: 1370, 1399, 1403 are leap; 1400 is not.
  static bool _isJalaliLeap(int jy) =>
      const [1, 5, 9, 13, 17, 22, 26, 30].contains(jy % 33);

  /// Jalali date → Julian Day Number (verified against 12 historical
  /// anchors incl. the Unix epoch 1348-10-11 = 1970-01-01 and Farvardin 1,
  /// 1370 = 1991-03-21; the classic 2820-cycle formula drifts a day in the
  /// modern era, so this uses the 33-year cycle + a 1370 anchor instead).
  static int _jalaliToJdn(int jy, int jm, int jd) {
    // JDN of Farvardin 1, 1370 AP (21 March 1991, Gregorian).
    const anchor = 2448337;
    var days = 365 * (jy - 1370);
    if (jy >= 1370) {
      for (var y = 1370; y < jy; y++) {
        if (_isJalaliLeap(y)) days++;
      }
    } else {
      for (var y = jy; y < 1370; y++) {
        if (_isJalaliLeap(y)) days--;
      }
    }
    final monthPart = jm <= 7 ? (jm - 1) * 31 : 186 + (jm - 7) * 30;
    return anchor + days + monthPart + (jd - 1);
  }

  /// Coordinates for a birth city name, or null when unknown.
  static List<double>? coordsForCity(String? city) =>
      city == null ? null : kIranCityCoords[city];
}
