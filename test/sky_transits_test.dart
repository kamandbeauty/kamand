import 'package:flutter_test/flutter_test.dart';
import 'package:taalebin/data/content/astro_content.dart';
import 'package:taalebin/domain/horoscope/sky_transits.dart';

/// Tests for the astronomy-driven sky layer.
///
/// Golden values were produced by the validated Python twin
/// (tool/content_traditions.py — Sun/Moon series checked against Meeus'
/// own worked examples to ±0.01°).
void main() {
  group('SkyTransits — golden dates (UTC noon)', () {
    test('2026-10-07: Moon in Virgo, waning crescent', () {
      final t = DateTime.utc(2026, 10, 7, 12);
      expect(SkyTransits.moonSignIndex(t), 5); // Virgo
      expect(SkyTransits.moonPhase(t), 7); // waning crescent
      expect(SkyTransits.sunSignIndex(t), 6); // Libra
    });

    test('2026-03-20: Moon in Aries, new-moon phase (day before Nowruz)', () {
      final t = DateTime.utc(2026, 3, 20, 12);
      expect(SkyTransits.moonSignIndex(t), 0); // Aries
      expect(SkyTransits.moonPhase(t), 0); // new moon
      expect(SkyTransits.sunSignIndex(t), 11); // Pisces (last day)
    });

    test('2026-06-21: Moon in Virgo, waxing crescent', () {
      final t = DateTime.utc(2026, 6, 21, 12);
      expect(SkyTransits.moonSignIndex(t), 5); // Virgo
      expect(SkyTransits.moonPhase(t), 1);
    });

    test('1992-11-29: Moon in Aquarius, waxing crescent', () {
      final t = DateTime.utc(1992, 11, 29, 12);
      expect(SkyTransits.moonSignIndex(t), 10); // Aquarius
      expect(SkyTransits.moonPhase(t), 1);
    });

    test('2026-09-25 (Saturday): Moon in Pisces, waxing gibbous', () {
      final t = DateTime.utc(2026, 9, 25, 12);
      expect(SkyTransits.moonSignIndex(t), 11); // Pisces
      expect(SkyTransits.moonPhase(t), 3);
    });
  });

  group('Ptolemaic aspect by sign distance', () {
    test('all six aspect classes', () {
      // Moon in Leo (4):
      expect(SkyTransits.aspectToSun(4, 4), 0); // Leo Sun → conjunction
      expect(SkyTransits.aspectToSun(4, 2), 1); // Gemini Sun → sextile
      expect(SkyTransits.aspectToSun(4, 1), 2); // Taurus Sun → square
      expect(SkyTransits.aspectToSun(4, 0), 3); // Aries Sun → trine
      expect(SkyTransits.aspectToSun(4, 10), 4); // Aquarius Sun → opposition
      expect(SkyTransits.aspectToSun(4, 6), 5); // Libra Sun → none
    });

    test('aspect ordering matches the content bank', () {
      expect(AstroContent.aspects[0]['id'], 'conjunction');
      expect(AstroContent.aspects[1]['id'], 'sextile');
      expect(AstroContent.aspects[2]['id'], 'square');
      expect(AstroContent.aspects[3]['id'], 'trine');
      expect(AstroContent.aspects[4]['id'], 'opposition');
      expect(AstroContent.aspects[5]['id'], 'none');
    });
  });

  group('Chaldean weekday rulers', () {
    test('Saturday → Saturn … Friday → Venus', () {
      expect(SkyTransits.weekdayRulerIndex(DateTime.utc(2026, 10, 10)), 0); // Sat
      expect(SkyTransits.weekdayRulerIndex(DateTime.utc(2026, 10, 11)), 1); // Sun
      expect(SkyTransits.weekdayRulerIndex(DateTime.utc(2026, 10, 12)), 2); // Mon
      expect(SkyTransits.weekdayRulerIndex(DateTime.utc(2026, 10, 13)), 3); // Tue
      expect(SkyTransits.weekdayRulerIndex(DateTime.utc(2026, 10, 14)), 4); // Wed
      expect(SkyTransits.weekdayRulerIndex(DateTime.utc(2026, 10, 15)), 5); // Thu
      expect(SkyTransits.weekdayRulerIndex(DateTime.utc(2026, 10, 16)), 6); // Fri
      expect(AstroContent.weekdayRulers[0]['rulerFa'], 'زحل');
      expect(AstroContent.weekdayRulers[6]['rulerFa'], 'زهره');
    });
  });

  group('Elements and monthly seasons', () {
    test('classical element triplicities', () {
      expect(SkyTransits.elementOf(0), 'fire'); // Aries
      expect(SkyTransits.elementOf(1), 'earth'); // Taurus
      expect(SkyTransits.elementOf(2), 'air'); // Gemini
      expect(SkyTransits.elementOf(3), 'water'); // Cancer
      expect(SkyTransits.elementOf(4), 'fire'); // Leo
      expect(SkyTransits.elementOf(11), 'water'); // Pisces
    });

    test('week themes exist for every element and are deterministic', () {
      for (final el in ['fire', 'earth', 'air', 'water']) {
        expect(AstroContent.weekThemes[el]!.length, 3);
      }
      final a = SkyTransits.weeklyTheme(DateTime.utc(2026, 9, 25, 12));
      final b = SkyTransits.weeklyTheme(DateTime.utc(2026, 9, 25, 12));
      expect(a, b);
      // Moon in Pisces (water) on that Saturday → a water theme.
      expect(
        AstroContent.weekThemes['water']!.contains(a),
        isTrue,
      );
    });

    test('twelve Solar-Hijri months map to the zodiac year', () {
      expect(AstroContent.monthSeasons.length, 12);
      expect(AstroContent.monthSeasons[0]['sunSign'], 'حمل'); // فروردین
      expect(AstroContent.monthSeasons[6]['sunSign'], 'میزان'); // مهر
      expect(AstroContent.monthSeasons[11]['sunSign'], 'حوت'); // اسفند
      expect(SkyTransits.monthSeason(1)['month'], 1);
      expect(SkyTransits.monthSeason(13)['month'], 12); // clamped
    });
  });

  group('AstroContent integrity', () {
    test('bank sizes', () {
      expect(AstroContent.moonInSigns.length, 12);
      expect(AstroContent.moonPhases.length, 8);
      expect(AstroContent.aspects.length, 6);
      expect(AstroContent.weekdayRulers.length, 7);
      expect(AstroContent.monthSeasons.length, 12);
      expect(AstroContent.skyIntro.isNotEmpty, isTrue);
    });
  });
}
