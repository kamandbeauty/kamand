import 'package:flutter_test/flutter_test.dart';

import 'package:taalebin/data/settings/settings_service.dart';
import 'package:taalebin/domain/entitlement/entitlement.dart';

/// Rewarded-unlock entitlement rules (product spec §32/§33):
/// day-scoped and month-scoped unlocks are independent of each other
/// and of purchases; legacy payloads keep decoding.
void main() {
  test('codec round-trips a month-scoped rewarded unlock', () {
    const e = Entitlement(
      source: EntitlementSource.rewardedAd,
      rewardedUnlockMonth: '1405-07',
    );
    final d = EntitlementCodec.decode(EntitlementCodec.encode(e));

    expect(d.source, EntitlementSource.rewardedAd);
    expect(d.rewardedUnlockMonth, '1405-07');
    expect(d.unlocksMonthFor('1405-07'), isTrue);
    expect(d.unlocksMonthFor('1405-08'), isFalse);
    expect(d.hasPremium, isFalse);
  });

  test('month unlock never opens another month or the daily', () {
    const e = Entitlement(
      source: EntitlementSource.rewardedAd,
      rewardedUnlockMonth: '1405-07',
    );
    expect(e.unlocksDailyFor('1405-07-14'), isFalse);
    expect(e.unlocksMonthFor('1405-07'), isTrue);
    expect(e.unlocksMonthFor('1404-07'), isFalse);
  });

  test('day and month unlocks coexist', () {
    const e = Entitlement(
      source: EntitlementSource.rewardedAd,
      rewardedUnlockDay: '1405-07-14',
      rewardedUnlockMonth: '1405-07',
    );
    final d = EntitlementCodec.decode(EntitlementCodec.encode(e));
    expect(d.rewardedUnlockDay, '1405-07-14');
    expect(d.rewardedUnlockMonth, '1405-07');
    expect(d.unlocksDailyFor('1405-07-14'), isTrue);
    expect(d.unlocksMonthFor('1405-07'), isTrue);
  });

  test('legacy v1 payload without month still decodes', () {
    const legacy =
        '{"source":1,"plan":null,"validUntil":null,"rewardedUnlockDay":"1405-07-14","v":1}';
    final d = EntitlementCodec.decode(legacy);
    expect(d.rewardedUnlockDay, '1405-07-14');
    expect(d.rewardedUnlockMonth, isNull);
    expect(d.unlocksDailyFor('1405-07-14'), isTrue);
    expect(d.unlocksMonthFor('1405-07'), isFalse);
  });

  test('purchased premium unlocks every day and month', () {
    const e = Entitlement(
      source: EntitlementSource.purchased,
      plan: PremiumPlan.lifetime,
    );
    expect(e.hasPremium, isTrue);
    expect(e.unlocksDailyFor('1405-01-01'), isTrue);
    expect(e.unlocksMonthFor('1405-01'), isTrue);
  });
}
