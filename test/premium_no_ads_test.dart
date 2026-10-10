import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taalebin/domain/profile/profile.dart';
import 'package:taalebin/main.dart';
import 'package:taalebin/providers/app_providers.dart';
import 'package:taalebin/screens/home/daily_screen.dart';
import 'package:taalebin/screens/home/home_screen.dart';
import 'package:taalebin/screens/home/monthly_screen.dart';

/// Product rule (v1.13.1): in the premium version there are NO ads and NO
/// rewarded-ad flows at all — banners disappear and rewarded-unlock cards
/// never render, while premium content is shown directly. Free users, on
/// the other hand, do see the (labeled) ad surfaces.
///
/// This test drives the real app: free user sees banner + rewarded card →
/// promo code grants lifetime premium → every screen scrolls end-to-end
/// with zero ad surfaces.
void main() {
  final vertical = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );

  Future<void> settle(WidgetTester tester, {int frames = 6}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Scroll through the whole list proving no ad surface is ever built.
  Future<void> scrollAssertingNoAds(WidgetTester tester, Finder scrollable,
      {int steps = 14, bool up = false}) async {
    for (var i = 0; i < steps; i++) {
      await tester.drag(scrollable, Offset(0, up ? 450 : -450));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('تبلیغ'), findsNothing,
          reason: 'بنر تبلیغ برای کاربر پرمیوم نباید ساخته شود');
      expect(find.text('مشاهدهٔ تبلیغ'), findsNothing,
          reason: 'کارت ریوارد برای کاربر پرمیوم نباید ساخته شود');
    }
  }

  testWidgets('premium users see no ads and no rewarded flows anywhere',
      (tester) async {
    final services = AppServices.forTest();

    // A saved profile skips onboarding; splash (900ms) then MainShell.
    await services.profileRepository.saveProfile(const Profile(
      id: 'p1',
      name: 'ستاره',
      birthDate: '1370-08-15',
      birthTime: null,
      birthTimeKnown: false,
      birthCity: 'تهران',
      zodiacId: 'scorpio',
      isPrimary: true,
      createdAt: '2026-10-06T00:00:00Z',
      updatedAt: '2026-10-06T00:00:00Z',
    ));

    await tester.binding.setSurfaceSize(const Size(420, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const TaalebinApp(),
      ),
    );
    await settle(tester, frames: 12);

    final homeScrollable =
        find.descendant(of: find.byType(HomeScreen), matching: vertical);
    final dailyScrollable =
        find.descendant(of: find.byType(DailyScreen), matching: vertical);
    final monthlyScrollable =
        find.descendant(of: find.byType(MonthlyScreen), matching: vertical);

    // ── FREE USER: ad surfaces exist (test is not vacuous) ─────────
    // Daily: rewarded-unlock card + bottom banner.
    await tester.scrollUntilVisible(
      find.text('طالع کامل امروز (پرمیوم)'),
      300,
      scrollable: homeScrollable,
    );
    await tester.tap(find.text('طالع کامل امروز (پرمیوم)').first);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('مشاهدهٔ تبلیغ'),
      300,
      scrollable: dailyScrollable,
    );
    expect(find.text('مشاهدهٔ تبلیغ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('تبلیغ'),
      300,
      scrollable: dailyScrollable,
    );
    expect(find.text('تبلیغ'), findsWidgets);
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    // Home: thin banner after the 12-sign sky strip.
    await tester.scrollUntilVisible(
      find.text('تبلیغ'),
      400,
      scrollable: homeScrollable,
    );
    expect(find.text('تبلیغ'), findsWidgets);

    // ── PREMIUM: promo code grants lifetime premium ────────────────
    final element = tester.element(find.byType(Navigator).first);
    final container = ProviderScope.containerOf(element);
    final granted =
        await container.read(entitlementProvider.notifier).redeemPromo('TALEBIN1405');
    expect(granted, isTrue);
    await settle(tester);

    // Home, end to end (both directions): zero ad surfaces.
    await scrollAssertingNoAds(tester, homeScrollable, up: true);
    await scrollAssertingNoAds(tester, homeScrollable);

    // At the top now — Daily: content unlocked, rewarded card gone.
    await tester.scrollUntilVisible(
      find.text('طالع کامل امروز'),
      300,
      scrollable: homeScrollable,
    );
    await tester.tap(find.text('طالع کامل امروز').first);
    await settle(tester);
    expect(find.text('مشاهدهٔ تبلیغ'), findsNothing);
    expect(find.text('طالع کامل امروز'), findsWidgets);
    await scrollAssertingNoAds(tester, dailyScrollable);
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    // Monthly: report unlocked, rewarded card + banner gone.
    await tester.scrollUntilVisible(
      find.text('طالع ماهانه'),
      300,
      scrollable: homeScrollable,
    );
    await tester.tap(find.text('طالع ماهانه').first);
    await settle(tester);
    expect(find.text('مشاهدهٔ تبلیغ'), findsNothing);
    expect(find.text('گزارش پیشرفتهٔ ماه'), findsWidgets);
    await scrollAssertingNoAds(tester, monthlyScrollable);
  });
}
