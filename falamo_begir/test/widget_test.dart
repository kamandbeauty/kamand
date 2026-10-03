// تست دود (smoke test) برنامهٔ «فالمو بگیر»

import 'package:fale_hafez/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('اپ اجرا می‌شود؛ اسپلش و سپس صفحهٔ اصلی نمایش داده می‌شود',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // در ابتدا صفحهٔ اسپلش با نسخهٔ برنامه دیده می‌شود
    expect(find.text('نسخه برنامه 1.1'), findsOneWidget);

    // پس از پایان اسپلش (۳ ثانیه) صفحهٔ اصلی با دکمهٔ فال نمایش داده می‌شود
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('نیت کردم ، فالمو بگیر'), findsOneWidget);
  });
}
