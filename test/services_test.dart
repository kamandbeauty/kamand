import 'package:flutter_test/flutter_test.dart';

import 'package:factor_ruby/data/settings/settings_service.dart';
import 'package:factor_ruby/domain/entitlement/entitlement.dart';

void main() {
  group('EntitlementCodec', () {
    test('none round-trips', () {
      final e = const Entitlement.none();
      final decoded = EntitlementCodec.decode(EntitlementCodec.encode(e));
      expect(decoded.source, EntitlementSource.none);
      expect(decoded.hasPremium, isFalse);
    });

    test('purchased plan round-trips', () {
      final e = Entitlement(
        source: EntitlementSource.purchased,
        plan: PremiumPlan.yearly,
        validUntil: DateTime.utc(2027, 1, 1),
      );
      final decoded = EntitlementCodec.decode(EntitlementCodec.encode(e));
      expect(decoded.source, EntitlementSource.purchased);
      expect(decoded.plan, PremiumPlan.yearly);
      expect(decoded.hasPremium, isTrue);
      expect(decoded.validUntil!.year, 2027);
    });

    test('rewarded unlock day round-trips', () {
      final e = const Entitlement(
        source: EntitlementSource.rewardedAd,
        rewardedUnlockDay: '1405-07-15',
      );
      final decoded = EntitlementCodec.decode(EntitlementCodec.encode(e));
      expect(decoded.unlocksDailyFor('1405-07-15'), isTrue);
      expect(decoded.unlocksDailyFor('1405-07-16'), isFalse);
    });

    test('corrupted JSON never crashes — falls back to none', () {
      expect(EntitlementCodec.decode('not-json'), const Entitlement.none());
      expect(EntitlementCodec.decode('{"source":99}').source,
          EntitlementSource.values.last);
      expect(EntitlementCodec.decode(null), const Entitlement.none());
    });

    test('expired entitlement has no premium', () {
      final e = Entitlement(
        source: EntitlementSource.purchased,
        plan: PremiumPlan.monthly,
        validUntil: DateTime.utc(2000, 1, 1),
      );
      expect(e.hasPremium, isFalse);
    });

    test('lifetime plan always premium', () {
      final e = const Entitlement(
        source: EntitlementSource.purchased,
        plan: PremiumPlan.lifetime,
      );
      expect(e.hasPremium, isTrue);
    });
  });

  group('PremiumPlan helpers', () {
    test('id ↔ enum mapping', () {
      for (final plan in PremiumPlan.values) {
        expect(premiumPlanFromId(plan.id), plan);
      }
      expect(premiumPlanFromId('nope'), isNull);
      expect(premiumPlanFromId(null), isNull);
    });
  });

  group('AppSettings', () {
    test('defaults (dark theme, notifications off)', () {
      const s = AppSettings();
      expect(s.themeMode, ThemeModeSetting.dark);
      expect(s.notificationsEnabled, isFalse);
      expect(s.onboardingCompleted, isFalse);
      expect(s.notificationHour, 8);
    });

    test('copyWith', () {
      const s = AppSettings();
      final updated = s.copyWith(
        notificationsEnabled: true,
        notificationHour: 9,
        themeMode: ThemeModeSetting.system,
      );
      expect(updated.notificationsEnabled, isTrue);
      expect(updated.notificationHour, 9);
      expect(updated.themeMode, ThemeModeSetting.system);
      expect(updated.onboardingCompleted, isFalse);
    });
  });
}
