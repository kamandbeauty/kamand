import 'package:flutter_test/flutter_test.dart';

import 'package:taalebin/domain/compatibility/compatibility_engine.dart';
import 'package:taalebin/domain/horoscope/deterministic_random.dart';
import 'package:taalebin/domain/zodiac/zodiac_repository.dart';
import 'package:taalebin/data/content/app_content.dart';

void main() {
  const repository = LocalZodiacRepository();
  const engine = CompatibilityEngine(repository);
  final signs = repository.allSigns();

  group('Matrix properties', () {
    test('full 12×12 matrix computes without errors', () {
      for (final a in signs) {
        for (final b in signs) {
          final r = engine.compute(a.id, b.id);
          expect(r.scores.overall, inInclusiveRange(10, 99),
              reason: '${a.id}×${b.id}');
        }
      }
    });

    test('symmetry: compat(a,b) == compat(b,a)', () {
      for (var i = 0; i < 12; i++) {
        for (var j = 0; j < 12; j++) {
          final ab = engine.compute(signs[i].id, signs[j].id);
          final ba = engine.compute(signs[j].id, signs[i].id);
          expect(ab.scores.overall, ba.scores.overall,
              reason: '${signs[i].id}×${signs[j].id}');
          expect(ab.scores.love, ba.scores.love);
          expect(ab.scores.trust, ba.scores.trust);
        }
      }
    });

    test('deterministic across calls', () {
      final r1 = engine.compute('scorpio', 'taurus');
      final r2 = engine.compute('scorpio', 'taurus');
      expect(r1.scores.overall, r2.scores.overall);
      expect(r1.whyText, r2.whyText);
    });

    test('all dimension scores in 0..100', () {
      for (final a in signs) {
        for (final b in signs) {
          final s = engine.compute(a.id, b.id).scores;
          for (final v in [
            s.love,
            s.communication,
            s.attraction,
            s.trust,
            s.longTerm,
            s.overall,
          ]) {
            expect(v, greaterThanOrEqualTo(0));
            expect(v, lessThanOrEqualTo(100));
          }
        }
      }
    });
  });

  group('Aspect logic', () {
    test('distance → aspect mapping', () {
      expect(CompatibilityEngine.aspectForDistance(0), 'conjunction');
      expect(CompatibilityEngine.aspectForDistance(1), 'semisextile');
      expect(CompatibilityEngine.aspectForDistance(11), 'semisextile');
      expect(CompatibilityEngine.aspectForDistance(2), 'sextile');
      expect(CompatibilityEngine.aspectForDistance(10), 'sextile');
      expect(CompatibilityEngine.aspectForDistance(3), 'square');
      expect(CompatibilityEngine.aspectForDistance(9), 'square');
      expect(CompatibilityEngine.aspectForDistance(4), 'trine');
      expect(CompatibilityEngine.aspectForDistance(8), 'trine');
      expect(CompatibilityEngine.aspectForDistance(5), 'quincunx');
      expect(CompatibilityEngine.aspectForDistance(7), 'quincunx');
      expect(CompatibilityEngine.aspectForDistance(6), 'opposition');
    });

    test('same-element trines score higher than squares on average', () {
      final trine = engine.compute('aries', 'leo'); // fire trine
      final square = engine.compute('aries', 'cancer'); // fire-water square
      expect(trine.scores.overall, greaterThan(square.scores.overall));
    });

    test('why text is personalized with sign names', () {
      final r = engine.compute('scorpio', 'taurus');
      expect(r.whyText.contains('عقرب') || r.whyText.contains('ثور'), isTrue);
      expect(r.whyText.contains('{a}'), isFalse);
      expect(r.whyText.contains('{b}'), isFalse);
    });
  });

  group('Ranking', () {
    test('ranked list has 11 entries sorted descending', () {
      final ranked = engine.rankedFor('scorpio');
      expect(ranked.length, 11);
      for (var i = 1; i < ranked.length; i++) {
        expect(
          ranked[i - 1].scores.overall,
          greaterThanOrEqualTo(ranked[i].scores.overall),
        );
      }
      expect(ranked.any((r) => r.signB.id == 'scorpio'), isFalse);
    });
  });

  group('Level labels', () {
    test('labels exist for every level', () {
      for (final level in CompatibilityLevel.values) {
        expect(
          CompatibilityEngine.levelLabelFa(level).length,
          greaterThan(2),
        );
      }
    });
  });

  group('Round-14 synastry deep bank', () {
    test('every aspect carries dynamics, strengths, challenges and advice',
        () {
      final aspects = AppContent.compatibility['aspectTexts']!
          as Map<String, Object?>;
      const ids = [
        'conjunction', 'semisextile', 'sextile', 'square',
        'trine', 'quincunx', 'opposition',
      ];
      for (final id in ids) {
        final a = aspects[id]! as Map<String, Object?>;
        expect((a['dynamics']! as String).length, greaterThan(60),
            reason: id);
        expect((a['advice']! as String).length, greaterThan(40), reason: id);
        expect((a['strengths']! as List).length, 3, reason: id);
        expect((a['challenges']! as List).length, 3, reason: id);
      }
    });

    test('dimension guide covers the five scored dimensions', () {
      final guide =
          AppContent.compatibility['dimensionGuide']! as Map<String, Object?>;
      for (final key in [
        'love', 'communication', 'attraction', 'trust', 'longTerm'
      ]) {
        expect(guide[key], isA<String>(), reason: key);
        expect((guide[key]! as String).length, greaterThan(30));
      }
    });

    test('score bands are five, ordered and labeled', () {
      final bands = (AppContent.compatibility['scoreBands']! as List)
          .whereType<Map>()
          .toList();
      expect(bands.length, 5);
      final mins = bands.map((b) => b['min']! as int).toList();
      expect(mins, [85, 72, 60, 48, 0]);
      for (final b in bands) {
        expect(b['label']! as String, isNotEmpty);
        expect(b['meaning']! as String, isNotEmpty);
      }
    });

    test('method note explains the weights transparently', () {
      final note = AppContent.compatibility['methodNote']! as String;
      expect(note.contains('۲۸'), isTrue); // love weight in Persian digits
      expect(note.contains('بطلمیوسی'), isTrue);
      expect(note.contains('قطعی'), isTrue); // entertainment framing kept
    });
  });

  group('Deterministic helpers', () {
    test('clampInt', () {
      expect(clampInt(50, 0, 100), 50);
      expect(clampInt(-5, 0, 100), 0);
      expect(clampInt(150, 0, 100), 100);
    });
  });
}
