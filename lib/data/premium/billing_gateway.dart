import '../../domain/entitlement/entitlement.dart';
import '../settings/settings_service.dart';

/// Billing abstraction (product spec §33): a real store (Play Billing,
/// Cafe Bazaar, etc.) implements this interface later. v1 ships with
/// [UnavailableBillingGateway] — purchases are never faked.
abstract class BillingGateway {
  Future<bool> get isAvailable;
  Future<Entitlement?> purchase(PremiumPlan plan);
  Future<void> restore();
}

class UnavailableBillingGateway implements BillingGateway {
  const UnavailableBillingGateway();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<Entitlement?> purchase(PremiumPlan plan) async => null;

  @override
  Future<void> restore() async {}
}

/// Rewarded-ad abstraction (product spec §32): ads are always optional and
/// gate only a clearly-labeled single-day unlock. v1 ships a demo gateway
/// that is honestly labeled in UI — no real ad SDK is bundled.
abstract class RewardedAdGateway {
  Future<bool> get isAvailable;

  /// Shows the ad; resolves true when the reward is earned.
  Future<bool> show();
}

class DemoRewardedAdGateway implements RewardedAdGateway {
  const DemoRewardedAdGateway();

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<bool> show() async => true; // UI presents an honest "demo" flow.
}

/// Owns premium state. UI reads it; it is never a toggleable boolean.
class EntitlementService {
  EntitlementService(this._settingsService, this._billing, this._ads);

  final SettingsService _settingsService;
  final BillingGateway _billing;
  final RewardedAdGateway _ads;

  Entitlement _current = const Entitlement.none();

  Entitlement get current => _current;

  Future<Entitlement> load() async {
    final settings = await _settingsService.load();
    _current = EntitlementCodec.decode(settings.entitlementJson);
    return _current;
  }

  Future<Entitlement> attemptPurchase(PremiumPlan plan) async {
    final entitlement = await _billing.purchase(plan);
    if (entitlement != null) {
      _current = entitlement;
      await _persist();
    }
    return _current;
  }

  /// Rewarded unlock: full daily horoscope for [dayKey] only.
  Future<Entitlement> earnRewardedUnlock(String dayKey) async {
    if (!await _ads.isAvailable || !await _ads.show()) return _current;
    _current = Entitlement(
      source: EntitlementSource.rewardedAd,
      rewardedUnlockDay: dayKey,
      plan: _current.plan,
      validUntil: _current.validUntil,
    );
    await _persist();
    return _current;
  }

  Future<void> reset() async {
    _current = const Entitlement.none();
    await _persist();
  }

  Future<void> _persist() async {
    final settings = await _settingsService.load();
    await _settingsService.save(
      settings.copyWith(entitlementJson: EntitlementCodec.encode(_current)),
    );
  }
}
