// تست دیتاست آفلاین دیوان حافظ

import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/poem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // برای دسترسی به rootBundle/assets در تست لازم است
  TestWidgetsFlutterBinding.ensureInitialized();

  test('نگاه‌اسنپ‌شات: ۵۹۵ شعر در شش بخش دیوان', () async {
    // سنپ‌شات: این اعداد ترکیب *کنونیِ* دیتاست‌اند و قاعدهٔ تجاریِ
    // برنامه نیستند (منطق برنامه روانی فهرستِ بارگیری‌شده کار می‌کند،
    // نه روی عددِ ثابت). اگر شعری افزوده یا حذف شد، این تست تنها
    // ترکیبِ دیتاست را عمداً به‌روزرسانی می‌کند.
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

    expect(ids.length, poems.length,
        reason: 'هیچ شناسهٔ تکراری در دیتاست نیست');
    for (final poem in poems) {
      expect(poem.id, isNotEmpty, reason: 'شناسهٔ خالی مجاز نیست');
      expect(poem.verses.trim(), isNotEmpty, reason: poem.id);
      expect(poem.number, greaterThan(0), reason: poem.id);
      expect(poem.displayTitle.trim(), isNotEmpty, reason: poem.id);
      if (poem.title != null) {
        expect(poem.title!.trim(), isNotEmpty,
            reason: 'عنوانِ فیلد t یا null است یا متنِ مفید: ${poem.id}');
      }
    }
  });

  test('هیچ دو شعری در یک بخش شمارهٔ یکسان ندارند', () async {
    final poems = await DivanRepository.all();
    final seen = <String>{};
    for (final poem in poems) {
      final key = '${poem.category.name}:${poem.number}';
      expect(seen.add(key), isTrue,
          reason: 'شمارهٔ تکراری ${poem.number} در بخش '
              '«${poem.category.name}» (${poem.id})');
    }
    // کاربر با «غزل ۱۲» (بخش + شماره) به یک شعرِ معلوم مالک می‌رسد؛
    // شمارهٔ تکراری در بخش این ناوبری را دوپهلو و دیتاست را معیوب می‌کرد.
  });

  test('بخش‌های دیتاست فقط از شش بخش شناخته‌شدهٔ دیوان‌اند', () async {
    final poems = await DivanRepository.all();
    final cats = poems.map((p) => p.category).toSet();
    // کلید «c» نامعتبر هنگام بارگیری FormatException می‌اندازد؛ این
    // گارد کنترلی می‌گوید دیتای فعلی فقط بخش‌های رسمی دارد.
    expect(cats, unorderedEquals(PoemCategory.values.toSet()));
    // گارد: همهٔ بخش‌ها حداقل یک شعر دارند تا UI از بخشِ تهی کرش نکند
    for (final c in PoemCategory.values) {
      expect(await DivanRepository.byCategory(c), isNotEmpty,
          reason: c.name);
    }
  });

  test('همهٔ ۴۹۵ غزل تعبیر فال معتبر دارند', () async {
    final ghazals = await DivanRepository.byCategory(PoemCategory.ghazal);
    expect(ghazals.length, 495);
    for (final ghazal in ghazals) {
      expect(ghazal.meaning, isNotNull, reason: ghazal.id);
      expect(ghazal.meaning!.trim(), isNotEmpty, reason: ghazal.id);
      // تعبیر واقعی ثبت شده باشد، نه جای‌گذار (placeholder)
      expect(ghazal.meaning, isNot(contains('هنوز تعبیری ثبت نشده')),
          reason: ghazal.id);
      // تعبیر باید متنی معنادار و به‌اندازهٔ کافی گسترده باشد (حداقل چند جمله)
      expect(ghazal.meaning!.trim().length, greaterThan(100),
          reason: ghazal.id);
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

  test('انتخاب تصادفی از مجموعهٔ تهی خطای واضح می‌دهد (بدون کرشِ خام)',
      () {
    // راستی‌آزمایی: روی لیست خالی به جای RangeError مبهم، StateErrorِ
    // هدایت‌شده با پیامِ قابل‌دستۀعیب پرتاب می‌شود (empty-safe).
    expect(() => DivanRepository.pickRandom(const <Poem>[]),
        throwsA(isA<StateError>()));
  });

  test('یافتن شعر با شناسهٔ یکتا درست کار می‌کند', () async {
    final poem = await DivanRepository.findById('ghazal-1');
    expect(poem.number, 1);
    expect(poem.category, PoemCategory.ghazal);
    expect(poem.firstMesra.isNotEmpty, isTrue);
  });
}
