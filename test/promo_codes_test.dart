import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taalebin/data/premium/billing_gateway.dart';
import 'package:taalebin/data/premium/promo_codes.dart';
import 'package:taalebin/data/settings/settings_service.dart';
import 'package:taalebin/domain/entitlement/entitlement.dart';

/// Promo-code (launch campaign) tests.
void main() {
  group('PromoCodes', () {
    test('normalization is case/space/dash/persian-digit agnostic', () {
      expect(PromoCodes.normalize('talebin 1405'), 'TALEBIN1405');
      expect(PromoCodes.normalize('Talebin-1405'), 'TALEBIN1405');
      expect(PromoCodes.normalize('  TALEBIN1405  '), 'TALEBIN1405');
      expect(PromoCodes.normalize('talebin_1405'), 'TALEBIN1405');
      expect(PromoCodes.normalize('TALEBIN۱۴۰۵'), 'TALEBIN1405');
      expect(PromoCodes.normalize('talebin١٤٠٥'), 'TALEBIN1405');
    });

    test('lookup finds the launch campaign', () {
      final promo = PromoCodes.lookup('talebin-1405');
      expect(promo, isNotNull);
      expect(promo!.plan, PremiumPlan.lifetime);
      expect(promo.percentOff, 100);
      expect(PromoCodes.lookup('wrong-code'), isNull);
      expect(PromoCodes.lookup(''), isNull);
    });
  });

  group('Entitlement codec with promo source', () {
    test('round-trip', () {
      final e = Entitlement(source: EntitlementSource.promo, plan: PremiumPlan.lifetime);
      final decoded = EntitlementCodec.decode(EntitlementCodec.encode(e));
      expect(decoded.source, EntitlementSource.promo);
      expect(decoded.plan, PremiumPlan.lifetime);
      expect(decoded.hasPremium, isTrue);
    });

    test('promo source index is stable (backward compatible)', () {
      // Existing persisted records use indexes 0..2 — promo must be 3.
      expect(EntitlementSource.values.indexOf(EntitlementSource.promo), 3);
      expect(EntitlementSource.values.indexOf(EntitlementSource.purchased), 2);
    });
  });

  group('EntitlementService.redeemPromoCode', () {
    late EntitlementService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = SharedPreferencesSettingsService(
          await SharedPreferences.getInstance());
      service = EntitlementService(
        settings,
        const UnavailableBillingGateway(),
        const DemoRewardedAdGateway(),
      );
      await service.load();
    });

    test('valid code grants lifetime premium and persists', () async {
      final after = await service.redeemPromoCode('Talebin 1405');
      expect(after.hasPremium, isTrue);
      expect(after.source, EntitlementSource.promo);
      expect(after.plan, PremiumPlan.lifetime);

      // Persists across a fresh service over the same prefs.
      final settings2 = SharedPreferencesSettingsService(
          await SharedPreferences.getInstance());
      final service2 = EntitlementService(
        settings2,
        const UnavailableBillingGateway(),
        const DemoRewardedAdGateway(),
      );
      final reloaded = await service2.load();
      expect(reloaded.hasPremium, isTrue);
      expect(reloaded.source, EntitlementSource.promo);
    });

    test('invalid code changes nothing', () async {
      final after = await service.redeemPromoCode('nope');
      expect(after.hasPremium, isFalse);
      expect(after.source, EntitlementSource.none);
    });

    test('redeem is idempotent once premium', () async {
      await service.redeemPromoCode('TALEBIN1405');
      final again = await service.redeemPromoCode('TALEBIN1405');
      expect(again.hasPremium, isTrue);
      expect(again.source, EntitlementSource.promo);
    });
  });
}
