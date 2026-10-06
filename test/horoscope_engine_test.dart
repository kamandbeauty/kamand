import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:factor_ruby/domain/horoscope/deterministic_random.dart';
import 'package:factor_ruby/core/date/app_date.dart';
import 'package:factor_ruby/domain/horoscope/horoscope_engine.dart';
import 'package:factor_ruby/domain/zodiac/zodiac_repository.dart';

void main() {
  const repository = LocalZodiacRepository();
  const engine = HoroscopeEngine(repository);
  final signs = repository.allSigns();

  group('Deterministic hash vectors (cross-platform contract)', () {
    test('FNV-1a known answers', () {
      for (final entry in kFnv1aVectors.entries) {
        expect(fnv1a32(entry.key), entry.value,
            reason: 'fnv1a32("${entry.key}")');
      }
    });

    test('LCG known outputs for seed 12345', () {
      final rng = DetRandom(12345);
      for (final expected in kLcgVectorSeed12345) {
        expect(rng.nextUint32(), expected);
      }
    });

    test('same seed → same sequence', () {
      final a = DetRandom(987654321);
      final b = DetRandom(987654321);
      for (var i = 0; i < 100; i++) {
        expect(a.nextInt(97), b.nextInt(97));
      }
    });
  });

  group('Daily generation determinism', () {
    test('same sign + same date → identical horoscope (two users)', () {
      final d1 = engine.generateDaily(signs[7], Jalali(1405, 7, 14));
      final d2 = engine.generateDaily(signs[7], Jalali(1405, 7, 14));
      expect(d1.generalText, d2.generalText);
      expect(d1.loveText, d2.loveText);
      expect(d1.scores.love, d2.scores.love);
      expect(d1.lucky.color, d2.lucky.color);
    });

    test('different day → different base content (statistically)', () {
      var changed = 0;
      final base = engine.generateDaily(signs[3], Jalali(1405, 7, 14));
      for (var day = 15; day <= 24; day++) {
        final other = engine.generateDaily(signs[3], Jalali(1405, 7, day));
        if (other.generalText != base.generalText ||
            other.scores.overall != base.scores.overall) {
          changed++;
        }
      }
      expect(changed, greaterThan(7),
          reason: 'content should vary across days');
    });

    test('different sign, same day → different seed content', () {
      final a = engine.generateDaily(signs[0], Jalali(1405, 7, 14));
      final b = engine.generateDaily(signs[11], Jalali(1405, 7, 14));
      expect(a.scores.love != b.scores.love ||
          a.generalText != b.generalText, isTrue);
    });

    test('all scores within 0..100 and sane range', () {
      for (final sign in signs) {
        for (var m = 1; m <= 12; m++) {
          final h = engine.generateDaily(sign, Jalali(1405, m, m.clamp(1, 28)));
          for (final v in [
            h.scores.love,
            h.scores.career,
            h.scores.finance,
            h.scores.mood,
            h.scores.energy,
            h.scores.overall,
          ]) {
            expect(v, greaterThanOrEqualTo(0));
            expect(v, lessThanOrEqualTo(100));
          }
        }
      }
    });

    test('generated version stamped', () {
      final h = engine.generateDaily(signs[0], Jalali(1405, 1, 1));
      expect(h.generatedVersion, kHoroscopeGeneratedVersion);
    });

    test('day key format', () {
      final h = engine.generateDaily(signs[0], Jalali(1405, 7, 4));
      expect(h.date, '1405-07-04');
    });
  });

  group('Personalization layer', () {
    test('jitter is deterministic per profile and bounded to ±3', () {
      final base = 80;
      final j1 = HoroscopeEngine.personalJitter(
          'p1', 'scorpio', '1405-07-14', base);
      final j2 = HoroscopeEngine.personalJitter(
          'p1', 'scorpio', '1405-07-14', base);
      expect(j1, j2);
      expect(j1, inInclusiveRange(base - 3, base + 3));
    });

    test('clamped at boundaries', () {
      final low = HoroscopeEngine.personalJitter('pX', 'leo', '1405-01-01', 1);
      expect(low, greaterThanOrEqualTo(0));
      final high =
          HoroscopeEngine.personalJitter('pX', 'leo', '1405-01-01', 99);
      expect(high, lessThanOrEqualTo(100));
    });
  });

  group('Weekly generation', () {
    test('week has 7 days starting Saturday', () {
      final weekStart = Jalali(1405, 7, 12); // 2026-10-03, a Saturday
      final week = engine.generateWeekly(signs[7], weekStart);
      expect(week.days.length, 7);
      expect(AppDate.weekDayIndex(week.days[0].date), 0); // Saturday
      expect(AppDate.weekDayName(week.days[0].date), 'شنبه');
      expect(AppDate.weekDayName(week.days[6].date), 'جمعه');
      // average computed over 7 days
      final avg = week.average;
      expect(avg.overall, inInclusiveRange(0, 100));
    });

    test('same week → same summary', () {
      final w1 = engine.generateWeekly(signs[2], Jalali(1405, 7, 12));
      final w3 = engine.generateWeekly(signs[2], Jalali(1405, 7, 12));
      expect(w1.summaryText, w3.summaryText);
    });
  });

  group('Monthly generation', () {
    test('deterministic per month', () {
      final m1 = engine.generateMonthly(signs[4], 1405, 7);
      final m2 = engine.generateMonthly(signs[4], 1405, 7);
      expect(m1.focusText, m2.focusText);
      expect(m1.scores.overall, m2.scores.overall);
    });

    test('changes across months', () {
      var changed = 0;
      final base = engine.generateMonthly(signs[4], 1405, 7);
      for (var m = 1; m <= 12; m++) {
        final other = engine.generateMonthly(signs[4], 1405, m);
        if (other.focusText != base.focusText ||
            other.scores.overall != base.scores.overall) {
          changed++;
        }
      }
      expect(changed, greaterThan(3));
    });

    test('year change alters content (سال جدید)', () {
      final a = engine.generateMonthly(signs[4], 1405, 7);
      final b = engine.generateMonthly(signs[4], 1406, 7);
      expect(
        a.focusText != b.focusText || a.scores.love != b.scores.love,
        isTrue,
      );
    });
  });

  group('Content pools sanity', () {
    test('every sign has all pools non-empty', () {
      for (final s in signs) {
        expect(s.dailyGeneral.length, greaterThanOrEqualTo(6), reason: s.id);
        expect(s.dailyLove.length, greaterThanOrEqualTo(4), reason: s.id);
        expect(s.dailyWarning.length, greaterThanOrEqualTo(3), reason: s.id);
        expect(s.weeklySummaries.length, greaterThanOrEqualTo(3), reason: s.id);
        expect(s.monthlyFocus.length, greaterThanOrEqualTo(2), reason: s.id);
        expect(s.luckyColors.length, greaterThanOrEqualTo(4), reason: s.id);
        expect(s.luckyNumbers.length, greaterThanOrEqualTo(4), reason: s.id);
      }
    });

    test('no duplicate sentences inside a pool', () {
      for (final s in signs) {
        expect(s.dailyGeneral.toSet().length, s.dailyGeneral.length,
            reason: '${s.id} general has duplicates');
        expect(s.dailyLove.toSet().length, s.dailyLove.length,
            reason: '${s.id} love has duplicates');
      }
    });
  });
}
