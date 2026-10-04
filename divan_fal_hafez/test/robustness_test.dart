// تست‌های پوشش‌دهندهٔ اصلاحات پایداری و باگ‌های گزارش‌شده:
// نرمال‌سازی جستجوی فارسی، پارسر سخت‌گیر دیتاست، نگاشت گروهی شعرها،
// یک‌خوان بودن نسخه، پایداری دلخواه‌ها، به‌روزرسانی زندهٔ اندازهٔ قلم،
// و ریست شدن نگه‌داشتن اثر انگشت هنگام رفتن به پس‌زمینه.

import 'dart:io';

import 'package:fale_hafez/config.dart';
import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/poem.dart';
import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/divan_screen.dart';
import 'package:fale_hafez/niyyat_screen.dart';
import 'package:fale_hafez/poem_screen.dart';
import 'package:fale_hafez/util/persian_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setupGet(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService();
  await settings.load();
  await Get.deleteAll(force: true);
  Get.put<SettingsService>(settings, permanent: true);
  // پیش‌گرم کردن کش دیوان: خواندن assets در محیط fake-async فقط
  // با runAsync کامل می‌شود.
  await tester.runAsync(() => DivanRepository.all());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('نرمال‌سازی جستجوی فارسی', () {
    test('حروف عربی یکدست می‌شوند', () {
      expect(normalizePersian('كاسا'), 'کاسا');
      expect(normalizePersian('دنياي'), 'دنیای');
      expect(normalizePersian('جنة'), 'جنه');
    });

    test('اعراب و کشیده حذف می‌شوند', () {
      expect(normalizePersian('اَلا'), 'الا');
      expect(normalizePersian('حـافــظ'), 'حافظ');
    });

    test('نیم‌فاصله و فاصله‌های پیاپی مدیریت می‌شوند', () {
      expect(normalizePersian('نیم‌فاصله'), 'نیم فاصله');
      expect(normalizePersian('سلام   دنیا'), 'سلام دنیا');
    });

    test('ارقام فارسی به لاتین تبدیل می‌شوند', () {
      expect(normalizePersian('غزل ۱۲۳'), 'غزل 123');
      expect(normalizePersian('٤٥٦'), '456');
    });

    test('جستجوی عربی روی متن فارسی نتیجه می‌دهد', () {
      expect(persianContains('کاساً و ناولها', 'كاسا'), isTrue);
    });
  });

  group('پارسر دیتاست', () {
    test('کلیدهای معتبر بخش‌ها درست نگاشت می‌شوند', () {
      expect(PoemCategory.fromKey('ghazal'), PoemCategory.ghazal);
      expect(PoemCategory.fromKey('robaee'), PoemCategory.robaee);
      expect(PoemCategory.fromKey('masnavi'), PoemCategory.masnavi);
    });

    test('کلید نامعتبر دیتاست بی‌صدا نادیده گرفته نمی‌شود', () {
      // قبلاً fall-back به غزل بود و خرابی دیتاست پنهان می‌ماند
      expect(() => PoemCategory.fromKey('ghzal'), throwsFormatException);
      expect(() => PoemCategory.fromKey(''), throwsFormatException);
    });

    test('یافتن گروهی شعرها: ترتیب حفظ و ناموجودها حذف می‌شوند', () async {
      final poems =
          await DivanRepository.findByIds(['ghazal-2', 'bad-id', 'ghazal-1']);
      expect(poems.map((p) => p.id), ['ghazal-2', 'ghazal-1']);
    });
  });

  group('نسخهٔ برنامه', () {
    test('AppInfo.version با نسخهٔ pubspec.yaml یک‌خوان است', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
              multiLine: true)
          .firstMatch(pubspec);
      expect(match, isNotNull, reason: 'خط version در pubspec.yaml یافت نشد');
      expect(AppInfo.version, match!.group(1),
          reason: 'نسخهٔ نمایشی برنامه با pubspec.yaml ناهماهنگ است');
    });
  });

  group('تنظیمات و دلخواه‌ها', () {
    test('دلخواه‌ها روی دستگاه ذخیره و پس از load مجدد حفظ می‌شوند',
        () async {
      SharedPreferences.setMockInitialValues({});
      final first = SettingsService();
      await first.load();
      await first.toggleFavorite('ghazal-1');

      final reloaded = SettingsService();
      await reloaded.load();
      expect(reloaded.isFavorite('ghazal-1'), isTrue);
      expect(reloaded.isFavorite('ghazal-2'), isFalse);

      await reloaded.toggleFavorite('ghazal-1');
      final again = SettingsService();
      await again.load();
      expect(again.isFavorite('ghazal-1'), isFalse);
    });

    test('ضریب قلم در بازهٔ مجاز گیر می‌افتد', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();
      await settings.setPoemScale(10);
      expect(settings.poemScale, SettingsService.maxScale);
      await settings.setPoemScale(0);
      expect(settings.poemScale, SettingsService.minScale);
    });
  });

  group('رفتارهای ویجتی حساس', () {
    testWidgets(
        'تغییر اندازهٔ قلم در تنظیمات همان‌جا روی متن شعر اعمال می‌شود',
        (WidgetTester tester) async {
      await _setupGet(tester);
      await tester.pumpWidget(const GetMaterialApp(
        home: PoemScreen(poemId: 'ghazal-1'),
      ));
      await tester.pumpAndSettle();

      bool hasVerseSize(double size) => find
          .byWidgetPredicate(
              (w) => w is Text && w.style?.fontSize == size,
              )
          .evaluate()
          .isNotEmpty;

      // ضریب پیش‌فرض ۱.۰ → متن با قلم ۱۷
      expect(hasVerseSize(17.0), isTrue, reason: 'متن غزل با قلم پایه');

      // بزرگ کردن قلم از تنظیمات → AnimatedBuilder مقدار تازه را می‌گیرد
      // (باگ قبلی: fontScale بیرون از builder محاسبه می‌شد و کهنه می‌ماند)
      await Get.find<SettingsService>().setPoemScale(1.5);
      await tester.pump();
      expect(hasVerseSize(25.5), isTrue, reason: 'متن با ضریب ۱.۵');
      expect(hasVerseSize(17.0), isFalse);
    });

    testWidgets('نگه‌داشتن اثر انگشت با رفتن به پس‌زمینه ریست می‌شود',
        (WidgetTester tester) async {
      await _setupGet(tester);
      await tester.pumpWidget(const GetMaterialApp(home: NiyyatScreen()));
      await tester.pumpAndSettle();

      // شروع نگه‌داشتن انگشت
      final gesture = await tester
          .startGesture(tester.getCenter(find.byIcon(Icons.fingerprint)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      double hold() =>
          (tester.state(find.byType(NiyyatScreen)) as dynamic).holdProgress;

      expect(hold(), greaterThan(0),
          reason: 'انیمیشن نگه‌داشتن در حال پیشرفت است');

      // رفتن اپ به پس‌زمینه → انیمیشن نیمه‌کاره ریست می‌شود
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(hold(), 0);

      await gesture.up();
      await tester.pump();
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(NiyyatScreen), findsOneWidget);
    });

    testWidgets('جستجوی دیوان با حروف عربی (ك/ي) هم نتیجه می‌دهد',
        (WidgetTester tester) async {
      await _setupGet(tester);
      await tester.pumpWidget(const GetMaterialApp(home: DivanScreen()));
      await tester.pumpAndSettle();

      // مصرع معروف غزل اول «ادر کاسا» را با «ك» عربی جستجو می‌کنیم
      await tester.enterText(find.byType(TextField), 'كاسا');
      await tester.pumpAndSettle();
      expect(find.text('غزل 1'), findsOneWidget);
      expect(find.text('غزل 2'), findsNothing);

      // پاک کردن جستجو → فهرست کامل برمی‌گردد
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('غزل 2'), findsWidgets);
    });
  });
}
