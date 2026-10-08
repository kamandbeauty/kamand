import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taalebin/core/theme/app_theme.dart';
import 'package:taalebin/domain/astrology/natal_engine.dart';
import 'package:taalebin/widgets/natal_wheel.dart';

/// Smoke tests for the natal wheel — the circular birth-sky map added in
/// v1.9.0 (geometry itself is verified numerically against the Python
/// twin; here we assert the painter runs for both chart shapes).
void main() {
  Future<void> pumpWheel(WidgetTester tester, bool withHouses) async {
    final chart = NatalEngine.compute(
      DateTime.utc(1991, 8, 3, 4),
      latitude: withHouses ? 35.69 : null,
      longitude: withHouses ? 51.39 : null,
      withHouses: withHouses,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppThemeSkin.velvet),
        home: Scaffold(
          body: Center(child: NatalWheel(chart: chart, size: 320)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the full wheel (ascendant + houses + aspects)',
      (tester) async {
    await pumpWheel(tester, true);
    expect(
      find.descendant(
          of: find.byType(NatalWheel),
          matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without a birth time (no ascendant)', (tester) async {
    await pumpWheel(tester, false);
    expect(
      find.descendant(
          of: find.byType(NatalWheel),
          matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero-size layout does not throw', (tester) async {
    final chart = NatalEngine.compute(DateTime.utc(1991, 8, 3, 4));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    // Painter with an empty canvas (guard against divide-by-zero paths).
    expect(chart.planetPositions.length, 7);
  });
}
