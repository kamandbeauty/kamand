// تست دیتاست آفلاین دیوان حافظ

import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/poem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // برای دسترسی به rootBundle/assets در تست لازم است
  TestWidgetsFlutterBinding.ensureInitialized();

  test('کل آثار: ۵۹۵ شعر در شش بخش دیوان', () async {
    expect(await DivanRepository.count(), 595);
    expect(await DivanRepository.count(PoemCategory.ghazal), 495);
    expect(await DivanRepository.count(PoemCategory.robaee), 42);
    expect(await DivanRepository.count(PoemCategory.ghete), 34);
    expect(await DivanRepository.count(PoemCategory.ghaside), 3);
    expect(await DivanRepository.count(PoemCategory.montasab), 19);
    expect(await DivanRepository.count(PoemCategory.masnavi), 2);
  });

  test('همهٔ اشعار متن غیرخالی و شناسهٔ یکتا دارند', () async {
    final poems = await DivanRepository.all();
    final ids = poems.map((p) => p.id).toSet();

    expect(ids.length, poems.length);
    for (final poem in poems) {
      expect(poem.verses.trim(), isNotEmpty, reason: poem.id);
      expect(poem.displayTitle.trim(), isNotEmpty, reason: poem.id);
    }
  });

  test('همهٔ ۴۹۵ غزل تعبیر فال معتبر دارند', () async {
    final ghazals = await DivanRepository.byCategory(PoemCategory.ghazal);
    for (final ghazal in ghazals) {
      expect(ghazal.meaning, isNotNull, reason: ghazal.id);
      expect(ghazal.meaning!.trim(), isNotEmpty, reason: ghazal.id);
    }
  });

  test('فال تصادفی همیشه یک غزل معتبر با تعبیر است', () async {
    for (var i = 0; i < 30; i++) {
      final fal = await DivanRepository.randomGhazal();
      expect(fal.category, PoemCategory.ghazal);
      expect(fal.number, inInclusiveRange(1, 495));
      expect(fal.meaning, isNotNull);
    }
  });

  test('یافتن شعر با شناسهٔ یکتا درست کار می‌کند', () async {
    final poem = await DivanRepository.findById('ghazal-1');
    expect(poem.number, 1);
    expect(poem.category, PoemCategory.ghazal);
    expect(poem.firstMesra.isNotEmpty, isTrue);
  });
}
