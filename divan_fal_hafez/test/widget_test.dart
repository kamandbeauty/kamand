// تست دود (smoke test) برنامهٔ «دیوان و فال حافظ»

import 'package:fale_hafez/about.dart';
import 'package:fale_hafez/config.dart';
import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/falscreen.dart';
import 'package:fale_hafez/main.dart';
import 'package:fale_hafez/niyyat_screen.dart';
import 'package:fale_hafez/util/persian_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<MyApp> _buildApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService();
  await settings.load();
  await Get.deleteAll(force: true);
  Get.put<SettingsService>(settings, permanent: true);

  // پیش‌گرم کردن کش دیوان: خواندن JSON دیوان از assets یک I/O واقعی
  // است که در محیط fake-async تست ویجت فقط با runAsync کامل می‌شود.
  // اگر کش گرم نشود، اسپینر نامتناهی صفحهٔ دیوان pumpAndSettle را
  // با خطای timeout متوقف می‌کند.
  await tester.runAsync(() => DivanRepository.all());

  return MyApp(settings: settings);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('صفحهٔ معرفی، محتوای کامل حافظ و امضای استودیو را نشان می‌دهد',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen()),
    );
    await tester.pump();

    expect(find.text('معرفی حافظ و اپلیکیشن'), findsOneWidget);
    expect(
      find.text('به حریم کلام لسان‌الغیب، حافظ شیرازی خوش آمدید.'),
      findsOneWidget,
    );
    expect(find.text('محتوای این اپلیکیشن شامل:'), findsOneWidget);
    expect(find.text('حافظ؛ ترجمان‌الاسرار'), findsOneWidget);
    expect(find.text('طراحی شده در'), findsOneWidget);
    expect(find.text('استودیو جاوید'), findsOneWidget);
    expect(
      find.text('نسخه برنامه ${toPersianDigits(AppInfo.version)}'),
      findsOneWidget,
    );
  });

  testWidgets('اپ اجرا می‌شود؛ اسپلش و سپس صفحهٔ اصلی نمایش داده می‌شود',
      (WidgetTester tester) async {
    final app = await _buildApp(tester);
    await tester.pumpWidget(app);

    // در ابتدا صفحهٔ اسپلش با نسخهٔ برنامه دیده می‌شود
    // (متن از روی AppInfo.version ساخته می‌شود تا با هر بامپ به‌روز بماند)
    expect(find.text('نسخه برنامه ${toPersianDigits(AppInfo.version)}'),
        findsOneWidget);

    // پس از پایان اسپلش (۳ ثانیه) صفحهٔ اصلی با دکمه‌ها نمایش داده می‌شود
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('اشعار'), findsOneWidget);
    expect(find.text('گرفتن فال'), findsOneWidget);
    expect(find.text('اشعار دلخواه'), findsOneWidget);
    expect(find.text('تنظیمات'), findsOneWidget);
  });

  testWidgets('دیوان: چیپ‌های بخش‌ها، فهرست و صفحهٔ خواندن شعر',
      (WidgetTester tester) async {
    final app = await _buildApp(tester);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // ورود به دیوان
    await tester.tap(find.text('اشعار'));
    await tester.pumpAndSettle();

    // چیپ‌های بخش‌ها و اولین غزل دیده می‌شود
    expect(find.textContaining('غزلیات'), findsWidgets);
    expect(find.text('غزل ۱'), findsOneWidget);

    // باز کردن غزل اول - صفحهٔ خواندن با همهٔ دکمه‌ها
    await tester.tap(find.text('غزل ۱'));
    await tester.pumpAndSettle();

    expect(find.text('مشاهدهٔ تعبیر فال'), findsOneWidget);
    expect(find.text('بعدی'), findsOneWidget);
    expect(find.text('کپی'), findsOneWidget);
    expect(find.text('اشتراک‌گذاری'), findsOneWidget);
    expect(find.text('دلخواه'), findsOneWidget);
  });

  testWidgets('نیّت و فال: گرفتن فال با نگه‌داشتن اثر انگشت',
      (WidgetTester tester) async {
    final app = await _buildApp(tester);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // ورود به صفحهٔ نیّت
    await tester.tap(find.text('گرفتن فال'));
    await tester.pumpAndSettle();

    // صفحهٔ نیّت فقط آثار تصویری + اسکنر اثر انگشت دارد (بدون نوشته)
    expect(find.byType(NiyyatScreen), findsOneWidget);
    expect(find.byKey(const Key('fingerprint_print')), findsOneWidget);

    // نگه‌داشتن انگشت روی اثر انگشت (بیش از ۸۰۰ میلی‌ثانیه)
    // نکتهٔ تست: پمپِ یک‌بارهٔ طولانی انیمیشن را کامل نمی‌کند چون تیکر در
    // اولین فریم مبنای زمانش را می‌سازد؛ پس در دو گام جلو می‌رویم.
    final gesture = await tester
        .startGesture(
            tester.getCenter(find.byKey(const Key('fingerprint_print'))));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1600));
    await gesture.up();
    await tester.pumpAndSettle();

    // پس از اسکن، صفحهٔ فال باز می‌شود
    expect(find.byType(FalScreen), findsOneWidget);
  });

  testWidgets(
      'نیّت و فال: هر تکمیل اسکن فقط یک صفحهٔ فال باز می‌کند و بعد از '
      'بازگشت، دوباره می‌شود فال گرفت',
      (WidgetTester tester) async {
    final app = await _buildApp(tester);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('گرفتن فال'));
    await tester.pumpAndSettle();
    expect(find.byType(NiyyatScreen), findsOneWidget);

    Future<void> completeHold() async {
      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('fingerprint_print'))));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    // اسکنِ کامل → دقیقاً یک صفحهٔ فال (پوشِ دوباره اتفاق نمی‌افتد)
    await completeHold();
    expect(find.byType(FalScreen), findsOneWidget,
        reason: 'تکمیل اسکن فقط یک FalScreen باز می‌کند');
    await tester.pump(const Duration(seconds: 1)); // فریم‌های بعدی
    expect(find.byType(FalScreen), findsOneWidget,
        reason: 'هیچ pushِ مجددی در فریم‌های بعدی رخ نمی‌دهد');

    // بازگشت از فال → صفحهٔ نیّت آماده برای فالِ دوباره است
    Get.back();
    await tester.pumpAndSettle();
    expect(find.byType(FalScreen), findsNothing);
    expect(find.byType(NiyyatScreen), findsOneWidget);

    await completeHold();
    expect(find.byType(FalScreen), findsOneWidget,
        reason: 'فالِ دوم هم دقیقاً یک صفحه باز می‌کند');
  });
}
