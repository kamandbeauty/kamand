import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taalebin/core/theme/app_theme.dart';
import 'package:taalebin/widgets/themed_backdrop.dart';

/// ThemedBackdrop — the velvet skin's artwork layer (borderless UI).
void main() {
  Future<void> pumpWith(WidgetTester tester, AppThemeSkin skin) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(skin),
        home: const Scaffold(
          body: ThemedBackdrop(child: Center(child: Text('محتوا'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('velvet: artwork image paints without errors',
      (tester) async {
    await pumpWith(tester, AppThemeSkin.velvet);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('other skins: child passes straight through (no image)',
      (tester) async {
    await pumpWith(tester, AppThemeSkin.midnight);
    expect(find.byType(Image), findsNothing);
    expect(find.text('محتوا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backdrop adapts to any screen size without throwing',
      (tester) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpWith(tester, AppThemeSkin.velvet);
    expect(tester.takeException(), isNull);
  });
}
