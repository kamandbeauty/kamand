// تست‌های پوشش‌دهندهٔ اصلاحات پایداری و باگ‌های گزارش‌شده:
// نرمال‌سازی جستجوی فارسی، پارسر سخت‌گیر دیتاست، نگاشت گروهی شعرها،
// یک‌خوان بودن نسخه، پایداری دلخواه‌ها، به‌روزرسانی زندهٔ اندازهٔ قلم،
// و ریست شدن نگه‌داشتن اثر انگشت هنگام رفتن به پس‌زمینه.

import 'dart:convert';
import 'dart:io';

import 'package:fale_hafez/config.dart';
import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/poem.dart';
import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/divan_screen.dart';
import 'package:fale_hafez/falscreen.dart';
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

    test('ارقام فارسی، عربی و لاتین هم‌ارز می‌شوند', () {
      // جستجوی «غزل ۱» با هر نگارشِ رقم باید به یک عبارت واحد برسد
      expect(normalizePersian('غزل ۱'), 'غزل 1'); // یونیکد Farsi
      expect(normalizePersian('غزل ١'), 'غزل 1'); // یونیکد Arabic-Indic
      expect(normalizePersian('غزل 1'), 'غزل 1'); // Latin همان است
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

  group('صف سریالیِ ذخیره‌سازی روی دستگاه', () {
    test('تغییرات پیاپی: آخرین تغییرِ کاربر، آخرین وضعیتِ ذخیره‌است',
        () async {
      // مسابقهٔ نوشتن: اگر دو نوشت موازی هم‌زمان انجام شوند (بدون صف)،
      // ترتیبِ کامل‌شدن ممکن است برعکسِ صدور باشد و وضعیتِ قدیمی‌تر،
      // حاصل نهاییِ دیسک شود؛ صفِ سریالی ترتیبِ نهایی را تضمین می‌کند.
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();

      await settings.toggleFavorite('ghazal-1'); // موجود
      await settings.toggleFavorite('ghazal-2'); // موجود
      await settings.toggleFavorite('ghazal-1'); // حذف → netِ فقط ghazal-2
      await settings.setNote('ghazal-5', 'یادداشت سریع');
      await settings.setPoemScale(1.5);
      await settings.setPoemScale(1.8); // آخرین مقدارِ نهایی
      await settings.debugWritesIdle(); // صبر تا پایانِ زنجیرهٔ نوشتن

      final reloaded = SettingsService();
      await reloaded.load();
      expect(reloaded.favorites, unorderedEquals({'ghazal-2'}));
      expect(reloaded.noteFor('ghazal-5'), 'یادداشت سریع');
      expect(reloaded.poemScale, closeTo(1.8, 0.001));
    });
  });

  group('اعتبارسنجی هنگام بارگذاری تنظیمات', () {
    test('قلم نامعتبر، ضریب خارج از بازه، NaN و آخرین شعرِ خالی بازیابی می‌شوند',
        () async {
      SharedPreferences.setMockInitialValues({
        'poem_font_key': 'nastaliq', // در سیستم نیست → پیش‌فرض
        'poem_font_scale': 50.0, // بیرون از بازه → clamp
        'last_poem_id': '', // رشتهٔ خالی → null
      });
      final settings = SettingsService();
      await settings.load();
      expect(settings.fontKey, 'vazirmatn');
      expect(settings.poemScale, SettingsService.maxScale);
      expect(settings.lastPoemId, isNull);

      SharedPreferences.setMockInitialValues({
        'poem_font_scale': double.nan, // NaN → پیش‌فرض
      });
      final naned = SettingsService();
      await naned.load();
      expect(naned.poemScale, SettingsService.defaultScale);
    });

    test('دفترچهٔ فال با بیشتر از ۱۰۰ ورودی سرریز نمی‌شود', () async {
      final raw = <String>[
        for (var i = 1; i <= 150; i++)
          jsonEncode(
              {'id': 'ghazal-$i', 'n': i, 't': '2026-01-01T10:00:00.000'}),
      ];
      SharedPreferences.setMockInitialValues({'fal_history': raw});
      final settings = SettingsService();
      await settings.load();
      expect(settings.falHistory.length, SettingsService.maxFalHistory);
    });
  });

  group('مهر نسخهٔ طرح ذخیره‌سازی (prefs schema)', () {
    test('بارگذاری اولیه مهر نسخهٔ فعلی را روی دستگاه ثبت می‌کند', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();
      await settings.debugWritesIdle(); // نوشتنِ مهر هم از صف آمده است
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('prefs_schema_version'),
          SettingsService.currentSchemaVersion);

      // مهاجرتِ آینده مهرِ تازه‌تری را حفظ می‌کند (جاسازی + جلوگیری از رجک به عقب)
      SharedPreferences.setMockInitialValues({
        'prefs_schema_version':
            SettingsService.currentSchemaVersion + 1, // فرضی از آینده
      });
      final future = SettingsService();
      await future.load(); // نباید کرش کند
      expect(future.poemScale, SettingsService.defaultScale);
    });
  });

  group('افکتِ اثر انگشت', () {
    test('افکتِ ذخیره‌شدهٔ نامعتبر به جوهر (پیش‌فرض) بازمی‌گردد', () async {
      SharedPreferences.setMockInitialValues({
        'fingerprint_effect': 'wind', // افکت نامعتبر → پیش‌فرض
      });
      final settings = SettingsService();
      await settings.load();
      expect(settings.fingerprintEffect, 'ink');

      // مقدار معتبر حفظ می‌شود و دوباره load صحیح بازیابی می‌کند
      await settings.setFingerprintEffect('petal');
      expect(settings.fingerprintEffect, 'petal');
      await settings.debugWritesIdle();
      final reloaded = SettingsService();
      await reloaded.load();
      expect(reloaded.fingerprintEffect, 'petal');

      // افکتِ خارج از فهرست نادیده گرفته می‌شود (تغییری نمی‌کند)
      await reloaded.setFingerprintEffect('nonsense');
      expect(reloaded.fingerprintEffect, 'petal');
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

    /// اثرِ قابل‌مشاهدهٔ «در حال اسکن بودن»: رنگِ طلاییِ پیشرفتِ اسکن
    /// روی اثر انگشت ظاهر شده است (ویجت Opacityِ تحت‌الجریان دارای
    /// شفافیت غیر‌صفر). این اساس رفتار صفحه است که از حافظه‌ی درونی
    /// State (مثل holdProgress) جداست.
    Finder goldScanTint() => find.byWidgetPredicate(
          (w) => w is Opacity && w.opacity > 0.05,
        );

    testWidgets('نگه‌داشتن نیمه‌کاره با رهاکردن انگشت فال نمی‌دهد',
        (WidgetTester tester) async {
      await _setupGet(tester);
      await tester.pumpWidget(const GetMaterialApp(home: NiyyatScreen()));
      await tester.pumpAndSettle();

      // در حالت سکون هیچ رنگِ طلاییِ پیشرفت دیده نمی‌شود
      expect(goldScanTint(), findsNothing);

      // نگه‌داشتن تا ۵۰۰/۸۰۰ میلی‌ثانیه → پیشرفتِ ظاهری اثر انگشت
      final gesture = await tester
          .startGesture(
              tester.getCenter(find.byKey(const Key('fingerprint_print'))));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(goldScanTint(), findsOneWidget,
          reason: 'اثر انگشت با نگه‌داشتن در حال طلایی‌شدن است');

      // رها کردنِ زودتر از ۸۰۰ms → برگشت به حالت سکون، بدون باز شدن فال
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(FalScreen), findsNothing);
      expect(find.byType(NiyyatScreen), findsOneWidget);
      expect(goldScanTint(), findsNothing, reason: 'پیشرفت به‌کلی برگشت');
    });

    testWidgets(
        'رفتن به پس‌زمینه هنگام نگه‌داشتن: فال بعدِ رهاکردن باز نمی‌شود '
        'و پس از بازگشت دوباره می‌شود فال گرفت',
        (WidgetTester tester) async {
      await _setupGet(tester);
      await tester.pumpWidget(const GetMaterialApp(home: NiyyatScreen()));
      await tester.pumpAndSettle();

      // شروع نگه‌داشتن (۵۰۰/۸۰۰ میلی‌ثانیه پیشرفت)
      var gesture = await tester
          .startGesture(
              tester.getCenter(find.byKey(const Key('fingerprint_print'))));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(goldScanTint(), findsOneWidget,
          reason: 'اسکن پیش از خروج در حال پیشرفت است');

      // رفتن به پس‌زمینه و برگشت → پیشرفتِ نیمه‌کاره قطعاً ریست شده است
      // (نکته: API تغییر وضعیت سینک است و مقداری برنمی‌گرداند → بدون await)
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(goldScanTint(), findsNothing,
          reason: 'پیشرفتِ نیمه‌کاره بعد خروج ریست می‌شود');

      // رها کردنِ انگشت پس از بازگشت نباید ناگهان فال باز کند
      // (باگ قدیمی: انیمیشنِ نیمه‌کاره در پس‌زمینه به اتمام می‌رسید)
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(FalScreen), findsNothing,
          reason: 'فالِ شبح‌وار پس از بازگشت اتفاق نمی‌افتد');
      expect(find.byType(NiyyatScreen), findsOneWidget);

      // دوباره با انگشتِ محکم: نگه‌داشتنِ کامل به فال منتهی می‌شود و
      // دو ناوبری پشت‌سر هم ساخته نمی‌شود
      gesture = await tester
          .startGesture(
              tester.getCenter(find.byKey(const Key('fingerprint_print'))));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(FalScreen), findsOneWidget,
          reason: 'پس از بازگشت و نگه‌داشتن کامل، فال باز می‌شود');
    });

    testWidgets('افکتِ انتخاب‌شدهٔ اثر انگشت، نقاشِ متناسب را می‌سازد',
        (WidgetTester tester) async {
      await _setupGet(tester);

      // پیش‌فرض: افکتِ جوهر
      expect(Get.find<SettingsService>().fingerprintEffect, 'ink');
      await tester.pumpWidget(const GetMaterialApp(home: NiyyatScreen()));
      await tester.pumpAndSettle();
      expect(
          find.byWidgetPredicate((w) =>
              w is CustomPaint && w.painter is InkBloomPainter),
          findsOneWidget,
          reason: 'پیش‌فرضِ جوهر = نقاشِ جوهر');

      // گلبرگ → نقاشِ گلبرگ
      await Get.find<SettingsService>().setFingerprintEffect('petal');
      await tester.pumpWidget(const GetMaterialApp(home: NiyyatScreen()));
      await tester.pumpAndSettle();
      expect(
          find.byWidgetPredicate((w) =>
              w is CustomPaint && w.painter is PetalBloomPainter),
          findsOneWidget,
          reason: 'با انتخابِ گلبرگ، نقاشِ گلبرگ کشیده می‌شود');
      expect(
          find.byWidgetPredicate((w) =>
              w is CustomPaint && w.painter is InkBloomPainter),
          findsNothing);

      // و رفتارِ نگه‌داشتن عیناً کار می‌کند (طلایی‌شدن اثر انگشت)
      final gesture = await tester
          .startGesture(
              tester.getCenter(find.byKey(const Key('fingerprint_print'))));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
          find.byWidgetPredicate((w) => w is Opacity && w.opacity > 0.05),
          findsOneWidget,
          reason: 'افکتِ گلبرگ مسیرِ پیشرفتِ اسکن را حفظ می‌کند');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(FalScreen), findsNothing);
    });

    testWidgets('جستجوی دیوان با حروف عربی (ك/ي) هم نتیجه می‌دهد',
        (WidgetTester tester) async {
      await _setupGet(tester);
      await tester.pumpWidget(const GetMaterialApp(home: DivanScreen()));
      await tester.pumpAndSettle();

      // مصرع معروف غزل اول «ادر کاسا» را با «ك» عربی جستجو می‌کنیم
      // (پمپِ ۳۰۰ms: عبورِ صریحِ ساعتِ فیک از دیبانسِ ۲۵۰ms جستجو تا
      // تست وابسته به رفتارِ pumpAndSettle نسبت به تایمر نباشد)
      await tester.enterText(find.byType(TextField), 'كاسا');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('غزل ۱'), findsOneWidget);
      expect(find.text('غزل ۲'), findsNothing);

      // پاک کردن جستجو → فهرست کامل برمی‌گردد
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('غزل ۲'), findsWidgets);
    });
  });

  group('دفترچهٔ فال، یادداشت‌ها و پشتیبان‌گیری', () {
    Poem samplePoem(int n) => Poem(
          id: 'ghazal-$n',
          category: PoemCategory.ghazal,
          number: n,
          verses: 'مصرع آزمایشی',
        );

    test('دفترچهٔ فال تازه‌ترین را اول نگه می‌دارد و از سقف رد نمی‌شود',
        () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();

      for (var i = 1; i <= 120; i++) {
        await settings.recordFal(samplePoem(i));
      }
      expect(settings.falHistory.length, SettingsService.maxFalHistory);
      expect(settings.falHistory.first.number, 120);
    });

    test('سیاست تکرار در دفترچهٔ فال: تکرارِ پیاپیِ همان شعر ردیف نمی‌سازد',
        () async {
      // سیاست مستند: دو فالِ بلافاصله‌پیاپی از یک شعر → همان ردیف (زمان فقط
      // به‌روزرسانی می‌شود). بعداً شعرِ دیگر، شکافِ متوالیِ آن را می‌شکند.
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();

      await settings.recordFal(samplePoem(1));
      await settings.recordFal(samplePoem(1));
      expect(settings.falHistory.length, 1,
          reason: 'فالِ تکراریِ همان شعرِ بلافاصله قبلی، ردیفِ جدید نمی‌سازد');

      await settings.recordFal(samplePoem(2));
      expect(settings.falHistory.length, 2);

      // تکرارِ غیرمتوالیِ ghazal-1 دو رویدادِ واقعی مجزا است → ردیفِ جدید
      await settings.recordFal(samplePoem(1));
      expect(settings.falHistory.map((e) => e.poemId).toList(),
          ['ghazal-1', 'ghazal-2', 'ghazal-1'],
          reason: 'تکرارِ غیرمتوالی ردیفِ مستقل می‌سازد و ترتیب حفظ می‌شود');
    });

    test('ذخیره و حذف یادداشت شخصی', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();

      await settings.setNote('ghazal-1', 'یادداشت آزمایشی');
      expect(settings.noteFor('ghazal-1'), 'یادداشت آزمایشی');
      await settings.setNote('ghazal-1', '   ');
      expect(settings.noteFor('ghazal-1'), isNull);
    });

    test('پشتیبان‌گیری و بازیابی (v2): دلخواه، یادداشت، دفترچهٔ فال، '
        'قلم، ضریب قلم و ادامهٔ مطالعه', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();

      await settings.toggleFavorite('ghazal-1');
      await settings.setNote('ghazal-1', 'یادداشت مهم');
      await settings.recordFal(samplePoem(7));
      await settings.setFont('sahel');
      await settings.setPoemScale(1.4);
      await settings.saveLastPoemId('ghazal-3');
      await settings.setFingerprintEffect('petal');
      final backup = settings.exportBackup();
      expect(jsonDecode(backup),
          containsPair('v', SettingsService.currentBackupVersion));

      final restored = SettingsService();
      await restored.load();
      expect(await restored.importBackup(backup), isTrue);
      expect(restored.isFavorite('ghazal-1'), isTrue);
      expect(restored.noteFor('ghazal-1'), 'یادداشت مهم');
      expect(restored.falHistory.single.number, 7);
      expect(restored.fontKey, 'sahel');
      expect(restored.poemScale, closeTo(1.4, 0.001));
      expect(restored.lastPoemId, 'ghazal-3');
      expect(restored.fingerprintEffect, 'petal',
          reason: 'افکتِ انتخاب‌شده در نسخهٔ پشتیبان حفظ می‌شود');

      // ورودی نامعتبر هیچ داده‌ای را خراب نمی‌کند (commit اتمیک)
      expect(await restored.importBackup('متن الکی'), isFalse);
      expect(restored.isFavorite('ghazal-1'), isTrue);
    });

    test('نسخهٔ پشتیبان: نسخهٔ ۱ پذیرفته و نسخه‌های ناشناخته رد می‌شوند',
        () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();
      await settings.toggleFavorite('ghazal-2'); // دادهٔ موجود؛ جان می‌ماند

      // v1 قدیمی فقط اطلاعات شخصی دارد؛ ترجیحات همان پیش‌فرض می‌ماند
      final legacy = jsonEncode({
        'app': 'divan-fal-hafez',
        'v': 1,
        'favorites': ['ghazal-1'],
        'notes': {'ghazal-1': 'یادداشت قدیمی'},
      });
      expect(await settings.importBackup(legacy), isTrue);
      expect(settings.isFavorite('ghazal-1'), isTrue);
      expect(settings.isFavorite('ghazal-2'), isFalse,
          reason: 'بازیابی v1 فهرستِ موجود را پس از commit جایگزین می‌کند');
      expect(settings.fontKey, 'vazirmatn',
          reason: 'v1 قلم ندارد → پیش‌فرض می‌ماند');
      expect(settings.poemScale, SettingsService.defaultScale);

      // نسخهٔ ناشناخته یا بدون نسخه رد می‌شود و هیچ داده‌ای عوض نمی‌شود
      final before = settings.isFavorite('ghazal-1');
      expect(
          await settings.importBackup(jsonEncode(
              {'app': 'divan-fal-hafez', 'v': 3, 'favorites': []})),
          isFalse,
          reason: 'نسخهٔ ۳ نسخهٔ ناشناخته‌ای از آینده است');
      expect(
          await settings
              .importBackup(jsonEncode({'app': 'divan-fal-hafez'})),
          isFalse,
          reason: 'نسخهٔ پشتیبان بدون "v" رد می‌شود');
      expect(settings.isFavorite('ghazal-1'), before,
          reason: 'ورودیِ ردِشده هیچ تغییری ایجاد نمی‌کند');

      // اپِ دیگر یا متنِ نامعتبر نباید کاری کنند
      expect(
          await settings
              .importBackup(jsonEncode({'app': 'other-app', 'v': 2})),
          isFalse);
      expect(await settings.importBackup('{}'), isFalse);
    });

    test('فیلتر داده‌های جعلی نسبت به دیتاست: شناسه/شماره/ترجیحات نامعتبر',
        () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();

      final tampered = jsonEncode({
        'app': 'divan-fal-hafez',
        'v': 2,
        'favorites': ['ghazal-1', 'fake-poem', 'ghazal-999'],
        'notes': {'fake-poem': 'یادداشت خیالی', 'ghazal-2': 'درست'},
        'falHistory': [
          {
            'id': 'ghazal-7',
            'n': 7,
            't': DateTime.now().toIso8601String()
          }, // درست
          {
            'id': 'fake-poem',
            'n': 1,
            't': DateTime.now().toIso8601String()
          }, // شعر وجود ندارد
          {
            'id': 'ghazal-1',
            'n': 999,
            't': DateTime.now().toIso8601String()
          }, // شماره با دیتاست سازگار نیست
          {'rubbish': true}, // بدون کلیدهای لازم
        ],
        'font': 'nastaliq', // ناشناخته → پیش‌فرض
        'poemScale': 9.5, // بیرون از بازه → clamp
        'lastPoemId': 'fake-poem', // ناموجود → null
        'fingerprintEffect': 'wind', // افکت نامعتبر → پیش‌فرضِ جوهر
      });
      expect(await settings.importBackup(tampered), isTrue);
      expect(settings.favorites,
          unorderedEquals({'ghazal-1'}), reason: 'فقط شناسه‌های واقعی ماندند');
      expect(settings.noteFor('fake-poem'), isNull);
      expect(settings.noteFor('ghazal-2'), 'درست');
      expect(settings.falHistory.single.poemId, 'ghazal-7');
      expect(settings.fontKey, 'vazirmatn',
          reason: 'قلم نامعتبر به پیش‌فرض بازگردانده می‌شود');
      expect(settings.poemScale, SettingsService.maxScale);
      expect(settings.lastPoemId, isNull);
      expect(settings.fingerprintEffect, 'ink',
          reason: 'افکتِ نامعتبر به جوهرِ پیش‌فرض بازگردانده می‌شود');
    });

    test('سقف ۱۰۰ ورودی دفترچهٔ فال در بازیابیِ بزرگ رعایت می‌شود',
        () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();

      final many = <Map<String, dynamic>>[
        for (var i = 1; i <= 150; i++)
          {
            'id': 'ghazal-$i',
            'n': i,
            't': DateTime(2026, 1, 1, 10).toIso8601String()
          },
      ];
      final backup = jsonEncode({
        'app': 'divan-fal-hafez',
        'v': 2,
        'falHistory': many,
      });
      expect(await settings.importBackup(backup), isTrue);
      expect(settings.falHistory.length, SettingsService.maxFalHistory);
      expect(settings.falHistory.first.number, 1,
          reason: 'ترتیبِ ردیف‌های صحیح حفظ شده است');
    });

    test('ارقام لاتین به فارسی تبدیل می‌شوند', () {
      expect(toPersianDigits('غزل 123'), 'غزل ۱۲۳');
      expect(toPersianDigits('2026/10/04'), '۲۰۲۶/۱۰/۰۴');
    });
  });
}
