// تست دیتاست آفلاین فال‌ها

import 'package:fale_hafez/data/fal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // برای دسترسی به rootBundle/assets در تست لازم است
  TestWidgetsFlutterBinding.ensureInitialized();

  test('کل ۴۹۵ فال حافظ به‌صورت آفلاین داخل برنامه موجود است', () async {
    expect(await FalRepository.count(), 495);
  });

  test('تمام ۴۹۵ غزل و تعبیرها غیرخالی و شماره‌ها از ۱ تا ۴۹۵ ترتیبی‌اند',
      () async {
    final fals = await FalRepository.all();

    expect(fals.length, 495);
    for (var i = 0; i < fals.length; i++) {
      expect(fals[i].number, i + 1);
      expect(fals[i].verses.trim(), isNotEmpty);
      expect(fals[i].meaning.trim(), isNotEmpty);
    }
  });

  test('فال تصادفی همیشه معتبر است', () async {
    for (var i = 0; i < 50; i++) {
      final fal = await FalRepository.random();
      expect(fal.number, inInclusiveRange(1, 495));
      expect(fal.verses, isNotEmpty);
      expect(fal.meaning, isNotEmpty);
    }
  });
}
