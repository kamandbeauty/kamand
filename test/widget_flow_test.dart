import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:factor_ruby/app.dart';
import 'package:factor_ruby/data/settings/settings_service.dart';
import 'package:factor_ruby/main.dart';
import 'package:factor_ruby/providers/app_providers.dart';

/// Deterministic, timed pumps (never waits forever — spinners/animations
/// are finite so a few frames always suffice).
Future<void> settle(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Taps a bottom-nav tab by its label — scoped to the NavigationBar so
/// same-text labels elsewhere (e.g. the home tab's «عشق» score card)
/// never make the finder ambiguous.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  ));
}

void main() {
  // End-to-end UI flow test against in-memory services:
  // onboarding → home → tabs → partner → theme → wipe.
  testWidgets('onboarding completes, home renders, partner flow works',
      (tester) async {
    final services = AppServices.forTest();

    // Tall surface so every lazily-built list section exists for finders.
    await tester.binding.setSurfaceSize(const Size(420, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const TaleManApp(),
      ),
    );

    // Splash → onboarding (900ms splash timer + profile state).
    await settle(tester, frames: 12);

    // ── Onboarding: welcome ───────────────────────────────────────
    expect(find.text('خوش آمدی'), findsOneWidget);
    await tester.tap(find.text('شروع کنیم'));
    await settle(tester);

    // ── Name ──────────────────────────────────────────────────────
    expect(find.text('اسمت چیه؟'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ستاره');
    await settle(tester);
    await tester.tap(find.text('ادامه'));
    await settle(tester);

    // ── Birth date (default recent year, month 1, day 1) ─────────
    expect(find.text('تاریخ تولدت'), findsOneWidget);
    await tester.tap(find.text('ادامه'));
    await settle(tester);

    // ── Birth time (skip) ─────────────────────────────────────────
    expect(find.text('ساعت تولدت'), findsOneWidget);
    await tester.tap(find.text('ادامه'));
    await settle(tester);

    // ── City (optional — skip) ────────────────────────────────────
    expect(find.text('شهر تولدت'), findsOneWidget);
    await tester.tap(find.text('ادامه'));
    await settle(tester);

    // ── Result ────────────────────────────────────────────────────
    expect(find.textContaining('هستی'), findsWidgets);
    await tester.tap(find.text('ادامه'));
    await settle(tester);

    // ── Notification step → skip ──────────────────────────────────
    await tester.tap(find.text('فعلاً نه'));
    await settle(tester, frames: 14);

    // ── Home ──────────────────────────────────────────────────────
    expect(find.textContaining('سلام ستاره'), findsOneWidget);
    expect(find.text('طالع امروز تو'), findsOneWidget);
    expect(find.text('پیام امروز'), findsOneWidget);
    expect(find.text('نشانه‌های شانس امروز'), findsOneWidget);

    // Profile persisted with a valid zodiac.
    final profile = await services.profileRepository.primaryProfile();
    expect(profile, isNotNull);
    expect(profile!.name, 'ستاره');
    expect(profile.zodiacId, isNotEmpty);

    // ── Tab: برج من ───────────────────────────────────────────────
    await tapTab(tester, 'برج من');
    await settle(tester);
    expect(find.text('نقاط قوت'), findsOneWidget);
    expect(find.text('نقاط ضعف'), findsOneWidget);
    expect(find.text('در عشق'), findsOneWidget);
    expect(find.text('در دوستی'), findsOneWidget);

    // ── Tab: عشق ──────────────────────────────────────────────────
    await tapTab(tester, 'عشق');
    await settle(tester);
    expect(find.text('با چه برج‌هایی هماهنگ هستی؟'), findsOneWidget);
    expect(find.textContaining('هنوز کسی را برای مقایسه'), findsOneWidget);

    // Add partner through the form.
    await tester.tap(find.text('افزودن شریک'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'ماهی');
    await settle(tester);
    await tester.tap(find.text('افزودن'));
    await settle(tester, frames: 12);

    final partner =
        await services.profileRepository.partnerForProfile(profile.id);
    expect(partner, isNotNull);
    expect(partner!.name, 'ماهی');
    expect(partner.zodiacId, isNotEmpty);

    // ── Tab: پروفایل ──────────────────────────────────────────────
    await tapTab(tester, 'پروفایل');
    await settle(tester);
    expect(find.text('ویرایش اطلاعات'), findsOneWidget);
    expect(find.text('حریم خصوصی'), findsOneWidget);

    // ── Theme switch to light via settings ────────────────────────
    await tester.tap(find.text('ظاهر برنامه'));
    await settle(tester);
    await tester.tap(find.text('روشن'));
    await settle(tester);
    final settings = await services.settingsService.load();
    expect(settings.themeMode, ThemeModeSetting.light);

    // ── Delete all data → back to onboarding ──────────────────────
    await tester.tap(find.text('حذف تمام اطلاعات من'));
    await settle(tester);
    await tester.tap(find.text('حذف کن'));
    await settle(tester, frames: 14);
    expect(find.text('خوش آمدی'), findsOneWidget);
    expect(await services.profileRepository.primaryProfile(), isNull);
  });

  testWidgets('AppGate renders splash without a crash', (tester) async {
    final services = AppServices.forTest();
    // AppGate lives under TaleManApp's MaterialApp (Directionality + RTL).
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const TaleManApp(),
      ),
    );
    await settle(tester, frames: 4);
    expect(find.byType(AppGate), findsOneWidget);
    await settle(tester, frames: 10);
  });
}
