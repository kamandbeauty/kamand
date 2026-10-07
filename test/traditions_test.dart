import 'package:flutter_test/flutter_test.dart';
import 'package:taalebin/data/content/traditions_content.dart';
import 'package:taalebin/domain/traditions/chinese_zodiac.dart';
import 'package:taalebin/domain/traditions/manazil.dart';
import 'package:taalebin/domain/traditions/numerology.dart';
import 'package:taalebin/domain/traditions/sky_math.dart';
import 'package:taalebin/domain/traditions/tzolkin.dart';
import 'package:taalebin/domain/traditions/vedic.dart';

/// Domain tests for the five world-tradition calculators.
///
/// Reference values were produced by the validated Python twin in
/// tool/content_traditions.py (Sun ±0.01° / Moon ±0.01° vs Meeus' own
/// worked examples; Chinese New Year from the official published table).
void main() {
  group('SkyMath', () {
    test('Julian Day at J2000 epoch', () {
      expect(SkyMath.julianDay(DateTime.utc(2000, 1, 1, 12)), closeTo(2451545.0, 1e-6));
    });

    test('JDN of the 13.0.0.0.0 anchor date', () {
      expect(SkyMath.julianDayNumber(DateTime.utc(2012, 12, 21)), 2456283);
    });

    test('Sun longitude at Meeus example 25.a (within low-precision)', () {
      // 1992-10-13 0h TD: apparent lambda = 199.90895°.
      final got = SkyMath.sunLongitude(2448908.5);
      expect(got, closeTo(199.909, 0.05));
    });

    test('Moon longitude at Meeus example 47.a', () {
      // 1992-04-12 0h TD: lambda = 133.167265° (full series).
      final got = SkyMath.moonLongitude(2448724.5);
      expect(got, closeTo(133.167, 0.05));
    });

    test('longitudes stay in [0, 360) across a wide range', () {
      for (final jd in [1500000.0, 2000000.0, 2451545.0, 2500000.0]) {
        final s = SkyMath.sunLongitude(jd);
        final m = SkyMath.moonLongitude(jd);
        expect(s, greaterThan(0.0));
        expect(s, lessThan(360.0));
        expect(m, greaterThan(0.0));
        expect(m, lessThan(360.0));
      }
    });
  });

  group('Chinese zodiac', () {
    test('year boundary follows the official CNY table', () {
      // 1984-02-02 was CNY (rat starts); the day before is still pig.
      expect(ChineseZodiacCalculator.lunarYearFor(DateTime.utc(1984, 2, 2)), 1984);
      expect(ChineseZodiacCalculator.lunarYearFor(DateTime.utc(1984, 2, 1)), 1983);
      expect(ChineseZodiacCalculator.lunarYearFor(DateTime.utc(2000, 2, 5)), 2000);
      expect(ChineseZodiacCalculator.lunarYearFor(DateTime.utc(2000, 2, 4)), 1999);
      expect(ChineseZodiacCalculator.lunarYearFor(DateTime.utc(2026, 2, 17)), 2026);
      expect(ChineseZodiacCalculator.lunarYearFor(DateTime.utc(2026, 2, 16)), 2025);
      // 2034: the famous leap-11th year — CNY is 19 Feb, not 20 Jan.
      expect(ChineseZodiacCalculator.lunarYearFor(DateTime.utc(2034, 2, 19)), 2034);
      expect(ChineseZodiacCalculator.lunarYearFor(DateTime.utc(2034, 1, 20)), 2033);
    });

    test('animal, element and polarity', () {
      final rat84 = ChineseZodiacCalculator.signFor(DateTime.utc(1984, 2, 2));
      expect(rat84.animalIndex, 0); // rat
      expect(rat84.elementIndex, 0); // wood
      expect(rat84.yang, isTrue); // jia (yang wood)

      final horse26 = ChineseZodiacCalculator.signFor(DateTime.utc(2026, 2, 17));
      expect(horse26.animalIndex, 6); // horse
      expect(horse26.elementIndex, 1); // fire
      expect(horse26.yang, isTrue); // bing (yang fire)

      final rooster17 = ChineseZodiacCalculator.signFor(DateTime.utc(2017, 6, 1));
      expect(rooster17.animalIndex, 9); // rooster
      expect(rooster17.elementIndex, 1); // fire
      expect(rooster17.yang, isFalse); // ding (yin fire)
    });

    test('compatibility levels', () {
      // rat(0) & dragon(4): San He triad — high.
      expect(ChineseZodiacCalculator.compatibility(0, 4), 'high');
      // rat & ox(1): Liu He pair — high.
      expect(ChineseZodiacCalculator.compatibility(0, 1), 'high');
      // rat & horse(6): Chong clash — low.
      expect(ChineseZodiacCalculator.compatibility(0, 6), 'low');
      // rat & tiger(2): no rule — medium.
      expect(ChineseZodiacCalculator.compatibility(0, 2), 'medium');
    });
  });

  group('Numerology', () {
    test('reduction preserves master numbers', () {
      expect(NumerologyCalculator.reduce(29), 11);
      expect(NumerologyCalculator.reduce(11), 11);
      expect(NumerologyCalculator.reduce(22), 22);
      expect(NumerologyCalculator.reduce(2929), 22);
      expect(NumerologyCalculator.reduce(1992), 3);
      expect(NumerologyCalculator.reduce(0), 0);
    });

    test('life path (three-cycle method)', () {
      expect(NumerologyCalculator.lifePath(DateTime.utc(1992, 11, 29)), 7);
      expect(NumerologyCalculator.lifePath(DateTime.utc(2000, 1, 1)), 4);
      // 1990-11-11: 11 + 11 + 1 = 23 -> 5.
      expect(NumerologyCalculator.lifePath(DateTime.utc(1990, 11, 11)), 5);
    });

    test('personal year', () {
      expect(
        NumerologyCalculator.personalYear(DateTime.utc(1992, 11, 29), 2026),
        5, // 11 + 11 + 1 = 23 -> 5.
      );
    });

    test('abjad values', () {
      // ع(70) + ل(30) + ی(10) = 110 -> 2.
      expect(NumerologyCalculator.abjadValue('علی'), 110);
      expect(NumerologyCalculator.abjadReduced(110), 2);
      expect(NumerologyCalculator.abjadValue('محمد'), 92); // م40+ح8+م40+د4
      expect(NumerologyCalculator.abjadValue(''), 0);
      // ZWNJ / spaces are ignored.
      expect(NumerologyCalculator.abjadValue('علی م'), 150);
    });
  });

  group('Tzolkin', () {
    test('anchor: 21 Dec 2012 is 4 Ajaw', () {
      final day = TzolkinCalculator.forDate(DateTime.utc(2012, 12, 21));
      expect(day.tone, 4);
      expect(day.nawalIndex, 19); // Ajaw
    });

    test('next day advances both wheels', () {
      final day = TzolkinCalculator.forDate(DateTime.utc(2012, 12, 22));
      expect(day.tone, 5);
      expect(day.nawalIndex, 0); // Imix
    });

    test('reference values (true Julian Day Numbers)', () {
      // Derived from the 4-Ajaw anchor by exact modular arithmetic.
      final a = TzolkinCalculator.forDate(DateTime.utc(1984, 2, 2));
      expect(a.tone, 10);
      expect(a.nawalIndex, 9); // Lamat

      final b = TzolkinCalculator.forDate(DateTime.utc(2026, 2, 17));
      expect(b.tone, 13);
      expect(b.nawalIndex, 5); // Manik'
    });
  });

  group('Vedic (sidereal Moon)', () {
    test('python-twin reference: 1992-11-29', () {
      final chart = VedicCalculator.forDateTime(DateTime.utc(1992, 11, 29, 12));
      expect(chart.siderealMoon, closeTo(283.645, 0.02));
      expect(chart.rashiIndex, 9);
      expect(chart.nakshatraIndex, 21);
      expect(chart.pada, 2);
    });

    test('python-twin reference: 2026-02-17', () {
      final chart = VedicCalculator.forDateTime(DateTime.utc(2026, 2, 17, 12));
      expect(chart.siderealMoon, closeTo(304.597, 0.02));
      expect(chart.rashiIndex, 10);
      expect(chart.nakshatraIndex, 22);
      expect(chart.pada, 4);
    });

    test('indices are consistent with the longitude', () {
      final chart = VedicCalculator.forDateTime(DateTime.utc(2000, 2, 5, 12));
      expect(chart.rashiIndex, (chart.siderealMoon ~/ 30) % 12);
      expect(chart.nakshatraIndex, (chart.siderealMoon / (360 / 27)).floor());
      expect(chart.pada, inInclusiveRange(1, 4));
    });
  });

  group('Manazil (28 lunar mansions)', () {
    test('python-twin references', () {
      expect(ManazilCalculator.indexFor(DateTime.utc(2000, 2, 5, 12)), 22);
      expect(ManazilCalculator.indexFor(DateTime.utc(2026, 2, 17, 12)), 23);
      expect(ManazilCalculator.indexFor(DateTime.utc(1984, 2, 2, 12)), 22);
    });

    test('today is always within 0..27', () {
      final i = ManazilCalculator.indexFor(DateTime.now().toUtc());
      expect(i, inInclusiveRange(0, 27));
    });
  });

  group('TraditionsContent integrity', () {
    test('table sizes', () {
      expect(TraditionsContent.chineseAnimals.length, 12);
      expect(TraditionsContent.chineseElements.length, 5);
      expect(TraditionsContent.iranianManazil.length, 28);
      expect(TraditionsContent.vedicRashis.length, 12);
      expect(TraditionsContent.vedicNakshatras.length, 27);
      expect(TraditionsContent.mayanNawals.length, 20);
      expect(TraditionsContent.mayanTones.length, 13);
      expect(TraditionsContent.numerologyNumbers.length, 12);
      expect(TraditionsContent.numerologyPersonalYear.length, 9);
      expect(TraditionsContent.abjadValues.isNotEmpty, isTrue);
    });

    test('CNY table covers 1900-2100 with plausible dates', () {
      final dates = TraditionsContent.chineseNewYearDates;
      expect(dates.length, 201);
      expect(TraditionsContent.chineseNewYearStartYear, 1900);
      for (final md in dates) {
        final m = int.parse(md.substring(0, 2));
        final d = int.parse(md.substring(3, 5));
        expect(m, inInclusiveRange(1, 2));
        if (m == 1) {
          expect(d, inInclusiveRange(21, 31));
        } else {
          expect(d, inInclusiveRange(1, 20));
        }
      }
      // Spot anchors.
      expect(dates[0], '01-31'); // 1900
      expect(dates[2026 - 1900], '02-17'); // 2026
      expect(dates[2034 - 1900], '02-19'); // leap-11th year
    });
  });
}
