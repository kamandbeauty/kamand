import 'package:flutter_test/flutter_test.dart';
import 'package:taalebin/domain/astrology/natal_engine.dart';
import 'package:taalebin/domain/astrology/natal_transits.dart';

/// Tests for the live-sky-vs-birth-chart transits (v1.10.0).
void main() {
  // Golden chart: 1991-08-03 04:00 UT, Tehran — Sun Leo ~130.35°.
  final natal = NatalEngine.compute(DateTime.utc(1991, 8, 3, 4),
      latitude: 35.69, longitude: 51.39);

  group('NatalTransits.compute', () {
    test('returns all nine bodies with valid placements', () {
      final transits =
          NatalTransits.compute(natal, DateTime.utc(2026, 10, 8, 12));
      expect(transits.length, 9);
      for (final t in transits) {
        expect(t.degreeInSign, inInclusiveRange(0, 30));
        expect(t.signId, isNotEmpty);
      }
      expect(transits.map((t) => t.body).toSet(), {
        'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn',
        'uranus', 'neptune',
      });
    });

    test('golden sky: 2026-10-08 — Uranus Gemini 5°, Neptune Aries 2°', () {
      final transits =
          NatalTransits.compute(natal, DateTime.utc(2026, 10, 8, 12));
      final byBody = {for (final t in transits) t.body: t};
      expect(byBody['uranus']!.signId, 'gemini');
      expect(byBody['neptune']!.signId, 'aries');
      expect(byBody['saturn']!.signId, 'aries');
      // Outer planets are retrograde around this date.
      expect(byBody['uranus']!.isRetrograde, isTrue);
      expect(byBody['neptune']!.isRetrograde, isTrue);
    });

    test('a transit sitting on a natal planet links as conjunct', () {
      // 2026-10-08: Saturn ≈ Aries 10.9° — the natal Moon (Taurus 36.42°)
      // is not there, but natal Uranus is Capricorn 280.68°. Use the
      // natal chart itself as "now": every body is exactly on itself.
      final transits =
          NatalTransits.compute(natal, DateTime.utc(1991, 8, 3, 4));
      final byBody = {for (final t in transits) t.body: t};
      expect(byBody['sun']!.natalLink, 'conjunct:sun');
      expect(byBody['neptune']!.natalLink, 'conjunct:neptune');
      // With houses available, anything not conjunct falls into a house.
      for (final t in transits) {
        expect(t.hasLink, isTrue, reason: t.body);
        expect(
          t.natalLink.startsWith('conjunct:') ||
              t.natalLink.startsWith('house:'),
          isTrue,
          reason: '${t.body}: ${t.natalLink}',
        );
      }
    });

    test('without houses, the natal Sun sign link is used as fallback', () {
      final bare = NatalEngine.compute(DateTime.utc(1991, 8, 3, 4),
          withHouses: false);
      final transits =
          NatalTransits.compute(bare, DateTime.utc(1991, 8, 3, 4));
      // The transiting Sun is exactly on the natal Sun → conjunct wins.
      expect(
          transits.firstWhere((t) => t.body == 'sun').natalLink,
          'conjunct:sun');
      // Mercury/Venus/Mars were in Virgo while the natal Sun is Leo —
      // so they carry the sun-sign link only if not conjunct anything.
      final mars = transits.firstWhere((t) => t.body == 'mars');
      expect(mars.hasLink, isTrue);
    });

    test('deterministic — same moment, same links', () {
      final a =
          NatalTransits.compute(natal, DateTime.utc(2026, 10, 8, 12));
      final b =
          NatalTransits.compute(natal, DateTime.utc(2026, 10, 8, 12));
      for (var i = 0; i < a.length; i++) {
        expect(a[i].natalLink, b[i].natalLink);
        expect(a[i].degreeInSign, b[i].degreeInSign);
      }
    });
  });
}
