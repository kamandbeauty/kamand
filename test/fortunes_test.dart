import 'package:flutter_test/flutter_test.dart';
import 'package:taalebin/data/content/fortunes_content.dart';
import 'package:taalebin/domain/fortunes/fortune_engines.dart';

/// Domain tests for the seven fortune modules.
void main() {
  group('GemOracle', () {
    test('birthstone maps to the Jalali month', () {
      expect(GemOracle.birthstoneFor(1)['nameFa'], 'عقیق سرخ');
      expect(GemOracle.birthstoneFor(5)['nameFa'], 'یاقوت سرخ');
      expect(GemOracle.birthstoneFor(12)['nameFa'], 'آب‌مرجان');
      // Out-of-range months are clamped, never crash.
      expect(GemOracle.birthstoneFor(0)['month'], 1);
      expect(GemOracle.birthstoneFor(13)['month'], 12);
    });

    test('daily draw is deterministic and picks 3 distinct stones', () {
      final a = GemOracle.dailyDraw('ستاره', '1405-07-15');
      final b = GemOracle.dailyDraw('ستاره', '1405-07-15');
      expect(a.length, 3);
      expect(b.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(a[i]['id'], b[i]['id']);
      }
      final ids = a.map((s) => s['id']).toSet();
      expect(ids.length, 3);
    });

    test('daily draw varies with name and day', () {
      final x = GemOracle.dailyDraw('ستاره', '1405-07-15');
      final y = GemOracle.dailyDraw('ماهتاب', '1405-07-15');
      expect(x.map((s) => s['id']).join(),
          isNot(equals(y.map((s) => s['id']).join())));
    });
  });

  group('AbjadFortune', () {
    test('letter values (shared table with the traditions module)', () {
      expect(AbjadFortune.valueOf('علی'), 110); // 70+30+10
      expect(AbjadFortune.valueOf('محمد'), 92);
      expect(AbjadFortune.valueOf(''), 0);
    });

    test('fortune is deterministic for the same day', () {
      final a = AbjadFortune.fortuneFor(
          name: 'علی', motherName: 'فاطمه', dayKey: '2026-10-07');
      final b = AbjadFortune.fortuneFor(
          name: 'علی', motherName: 'فاطمه', dayKey: '2026-10-07');
      expect(a, b);
      expect(FortunesContent.abjadFortunes, contains(a));
    });
  });

  group('GreekAstrology', () {
    test('humor and quality follow the classical scheme', () {
      expect(GreekAstrology.forSignId('aries')['humor'], 'choleric');
      expect(GreekAstrology.forSignId('aries')['quality'], 'cardinal');
      expect(GreekAstrology.forSignId('taurus')['humor'], 'melancholic');
      expect(GreekAstrology.forSignId('taurus')['quality'], 'fixed');
      expect(GreekAstrology.forSignId('gemini')['humor'], 'sanguine');
      expect(GreekAstrology.forSignId('gemini')['quality'], 'mutable');
      expect(GreekAstrology.forSignId('pisces')['humor'], 'phlegmatic');
    });

    test('unknown sign ids fall back safely', () {
      expect(GreekAstrology.forSignId('unknown')['id'], 'aries');
    });
  });

  group('MarriageAstrology & MonthTraits & SpiritAnimal', () {
    test('marriage profiles resolve per sign', () {
      final p = MarriageAstrology.forSignId('pisces');
      expect(p['bestFa'] as String, contains('سرطان'));
      expect((p['text']! as String).isNotEmpty, isTrue);
    });

    test('month traits map 1..12', () {
      expect(MonthTraits.forMonth(1)['title'], 'متولدین فروردین');
      expect(MonthTraits.forMonth(12)['title'], 'متولدین اسفند');
      expect(MonthTraits.forMonth(0)['month'], 1); // clamped
    });

    test('spirit animal per sign', () {
      expect(SpiritAnimal.forSignId('virgo')['animal'], 'جغد');
      expect(SpiritAnimal.forSignId('leo')['animal'], 'شیر');
      expect(SpiritAnimal.forSignId('capricorn')['animal'], 'پلنگ برفی');
    });
  });

  group('Tarot', () {
    test('birth card: digit-sum method', () {
      // year 21 + month 2 + day 11 = 34 -> 3+4 = 7 (The Chariot).
      expect(Tarot.birthCard(DateTime(1992, 11, 29)), 7);
      // 2+0+0+0+0+1+0+1 = 4 (The Emperor).
      expect(Tarot.birthCard(DateTime(2000, 1, 1)), 4);
      // 1+9+8+4+0+2+0+2 = 26 -> 8 (Strength).
      expect(Tarot.birthCard(DateTime(1984, 2, 2)), 8);
      // 2+0+0+2+0+9+0+9 = 22 -> The Fool.
      expect(Tarot.birthCard(DateTime(2002, 9, 9)), 0);
    });

    test('daily card is deterministic and in range', () {
      final a = Tarot.dailyCard('leo', '1405-07-15');
      final b = Tarot.dailyCard('leo', '1405-07-15');
      expect(a['index'], b['index']);
      expect(a['index'] as int, inInclusiveRange(0, 21));
    });

    test('all 22 cards present and unique', () {
      final names = FortunesContent.tarotCards
          .map((c) => c['nameFa']! as String)
          .toSet();
      expect(names.length, 22);
    });
  });

  group('FortunesContent integrity', () {
    test('table sizes', () {
      expect(FortunesContent.gemStones.length, 12);
      expect(FortunesContent.abjadFortunes.length, 24);
      expect(FortunesContent.greekSigns.length, 12);
      expect(FortunesContent.greekQualities.length, 3);
      expect(FortunesContent.greekHumors.length, 4);
      expect(FortunesContent.marriageSigns.length, 12);
      expect(FortunesContent.monthTraits.length, 12);
      expect(FortunesContent.tarotCards.length, 22);
      expect(FortunesContent.spiritAnimals.length, 12);
    });

    test('stones cover months 1..12 exactly once', () {
      final months = FortunesContent.gemStones
          .map((s) => s['month']! as int)
          .toList()
        ..sort();
      expect(months, List.generate(12, (i) => i + 1));
    });
  });
}
