import 'package:flutter_test/flutter_test.dart';
import 'package:taalebin/domain/astrology/natal_chart.dart';
import 'package:taalebin/domain/astrology/natal_engine.dart';
import 'package:taalebin/domain/traditions/sky_math.dart';

/// Tests for the offline natal engine.
///
/// Golden values come from the line-by-line Python twin
/// (tool/natal_engine_validate.py), which was checked against Meeus'
/// own worked examples (25.b Sun, 47.a Moon, 32.a Venus) and a live
/// 2026-10-03 ephemeris snapshot (all planets within 0.16°).
void main() {
  group('jalaliBirthToUtc — historical Iranian offsets', () {
    test('1370-05-12 08:30 → 1991-08-03 04:00 UTC (summer DST +4:30)', () {
      final utc = NatalEngine.jalaliBirthToUtc(1370, 5, 12, '08:30');
      expect(utc, DateTime.utc(1991, 8, 3, 4, 0));
    });

    test('1405-01-01 12:00 → 2026-03-21 08:30 UTC (no DST after 2021)', () {
      final utc = NatalEngine.jalaliBirthToUtc(1405, 1, 1, '12:00');
      expect(utc, DateTime.utc(2026, 3, 21, 8, 30));
    });

    test('1348-10-11 without time → 1970-01-01 08:30 UTC (noon, +3:30)', () {
      // Unix-epoch anchor: 1348-10-11 AP = 1970-01-01.
      final utc = NatalEngine.jalaliBirthToUtc(1348, 10, 11, null);
      expect(utc, DateTime.utc(1970, 1, 1, 8, 30));
    });

    test('invalid time falls back to noon', () {
      final utc = NatalEngine.jalaliBirthToUtc(1400, 7, 1, 'نامعتبر');
      expect(utc.hour, 8); // noon Tehran = 08:30 UTC
      expect(utc.minute, 30);
    });
  });

  group('compute — golden chart (1991-08-03 04:00 UT, Tehran)', () {
    final birth = DateTime.utc(1991, 8, 3, 4);
    final chart = NatalEngine.compute(birth,
        latitude: 35.69, longitude: 51.39);

    Map<String, PlanetPosition> byBody() => {
          for (final p in chart.planetPositions) p.body: p
        };

    test('seven classical bodies present', () {
      expect(chart.planetPositions.length, 7);
      expect(byBody().keys.toSet(), {
        'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn'
      });
    });

    test('Sun in Leo ~130.35°, Moon in Taurus ~36.42°', () {
      final pos = byBody();
      expect(pos['sun']!.signId, 'leo');
      expect((pos['sun']!.longitudeDegrees - 130.35).abs() < 0.05, isTrue);
      expect(pos['moon']!.signId, 'taurus');
      expect((pos['moon']!.longitudeDegrees - 36.42).abs() < 0.05, isTrue);
    });

    test('Mercury/Venus/Mars stellium in Virgo', () {
      final pos = byBody();
      expect(pos['mercury']!.signId, 'virgo');
      expect(pos['venus']!.signId, 'virgo');
      expect(pos['mars']!.signId, 'virgo');
    });

    test('Venus & Saturn retrograde; rest direct', () {
      final pos = byBody();
      expect(pos['venus']!.isRetrograde, isTrue);
      expect(pos['saturn']!.isRetrograde, isTrue);
      expect(pos['mercury']!.isRetrograde, isFalse);
      expect(pos['jupiter']!.isRetrograde, isFalse);
    });

    test('ascendant Virgo ~157.33°, MC Gemini ~64.59°', () {
      final asc = chart.ascendant!;
      expect(asc.signId, 'virgo');
      expect((asc.longitudeDegrees - 157.33).abs() < 0.1, isTrue);
      expect((asc.midheavenDegrees - 64.59).abs() < 0.1, isTrue);
    });

    test('twelve equal houses starting at the ascendant', () {
      expect(chart.houses.length, 12);
      expect(chart.houses.first.signId, chart.ascendant!.signId);
      final ascLon = chart.ascendant!.longitudeDegrees;
      for (var k = 0; k < 12; k++) {
        expect(chart.houses[k].index, k + 1);
        // Cusps are wrapped into 0–360 (like the ascendant itself).
        final expected = (ascLon + 30.0 * k) % 360.0;
        expect((chart.houses[k].cuspDegrees - expected).abs() < 1e-6, isTrue);
      }
    });

    test('Moon–Venus trine found (orb < 2°)', () {
      final mv = chart.aspects.firstWhere(
        (a) =>
            (a.bodyA == 'moon' && a.bodyB == 'venus') ||
            (a.bodyA == 'venus' && a.bodyB == 'moon'),
        orElse: () => throw StateError('moon-venus aspect missing'),
      );
      expect(mv.kind, 'trine');
      expect(mv.orbDegrees < 2, isTrue);
    });

    test('every aspect within its classical orb', () {
      const orbs = {
        'conjunction': 8.0,
        'sextile': 4.0,
        'square': 6.0,
        'trine': 7.0,
        'opposition': 8.0,
      };
      for (final a in chart.aspects) {
        expect(a.orbDegrees <= orbs[a.kind]!, isTrue,
            reason: '${a.bodyA}-${a.bodyB} ${a.kind}');
      }
    });
  });

  group('cross-checks', () {
    test('Sun from Earth elements agrees with the Meeus series (±0.05°)',
        () {
      final jd = SkyMath.julianDay(DateTime.utc(2026, 10, 3, 12));
      var diff =
          (NatalEngine.sunFromEarthElements(jd) - SkyMath.sunLongitude(jd))
              .abs();
      if (diff > 180) diff = 360 - diff;
      expect(diff < 0.05, isTrue);
    });

    test('no coordinates → no houses, planets still computed', () {
      final chart =
          NatalEngine.compute(DateTime.utc(1991, 8, 3, 4), withHouses: false);
      expect(chart.ascendant, isNull);
      expect(chart.houses, isEmpty);
      expect(chart.planetPositions.length, 7);
    });
  });
}
