// تست دود (smoke test) برنامهٔ «دیوان و فال حافظ»

import 'package:fale_hafez/data/divan_repository.dart';
import 'package:fale_hafez/data/settings_service.dart';
import 'package:fale_hafez/main.dart';
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

  testWidgets('اپ اجرا می‌شود؛ اسپلش و سپس صفحهٔ اصلی نمایش داده می‌شود',
      (WidgetTester tester) async {
    final app = await _buildApp(tester);
    await tester.pumpWidget(app);

    // در ابتدا صفحهٔ اسپلش با نسخهٔ برنامه دیده می‌شود
    expect(find.text('نسخه برنامه 1.3'), findsOneWidget);

    // پس از پایان اسپلش (۳ ثانیه) صفحهٔ اصلی با دکمه‌ها نمایش داده می‌شود
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('دیوان حافظ'), findsOneWidget);
    expect(find.text('نیت کردم ، فالمو بگیر'), findsOneWidget);
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
    await tester.tap(find.text('دیوان حافظ'));
    await tester.pumpAndSettle();

    // چیپ‌های بخش‌ها و اولین غزل دیده می‌شود
    expect(find.textContaining('غزلیات'), findsWidgets);
    expect(find.text('غزل 1'), findsOneWidget);

    // باز کردن غزل اول - صفحهٔ خواندن با همهٔ دکمه‌ها
    await tester.tap(find.text('غزل 1'));
    await tester.pumpAndSettle();

    expect(find.text('مشاهدهٔ تعبیر فال'), findsOneWidget);
    expect(find.text('بعدی'), findsOneWidget);
    expect(find.text('کپی'), findsOneWidget);
    expect(find.text('اشتراک‌گذاری'), findsOneWidget);
    expect(find.text('دلخواه'), findsOneWidget);
  });
}
