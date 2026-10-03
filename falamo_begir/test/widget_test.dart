// تست دود (smoke test) برنامهٔ «دیوان و فال حافظ»

import 'package:fale_hafez/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('اپ اجرا می‌شود؛ اسپلش و سپس صفحهٔ اصلی نمایش داده می‌شود',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // در ابتدا صفحهٔ اسپلش با نسخهٔ برنامه دیده می‌شود
    expect(find.text('نسخه برنامه 1.2'), findsOneWidget);

    // پس از پایان اسپلش (۳ ثانیه) صفحهٔ اصلی با دکمه‌های دیوان و فال نمایش داده می‌شود
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('دیوان حافظ'), findsOneWidget);
    expect(find.text('نیت کردم ، فالمو بگیر'), findsOneWidget);
  });

  testWidgets('دیوان حافظ: فهرست غزل‌ها و صفحهٔ خواندن غزل باز می‌شود',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // ورود به دیوان
    await tester.tap(find.text('دیوان حافظ'));
    await tester.pumpAndSettle();

    // فهرست غزل‌ها با اولین غزل دیوان بارگذاری شده است
    expect(find.text('غزل 1'), findsOneWidget);

    // باز کردن غزل اول
    await tester.tap(find.text('غزل 1'));
    await tester.pumpAndSettle();

    // صفحهٔ خواندن غزل با دکمهٔ تعبیر فال و پیمایش غزل‌ها
    expect(find.text('مشاهدهٔ تعبیر فال'), findsOneWidget);
    expect(find.text('غزل بعدی'), findsOneWidget);
  });
}
