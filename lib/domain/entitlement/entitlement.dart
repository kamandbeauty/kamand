/// Premium plans (product spec §33). Billing providers are abstracted so a
/// different store can be wired without touching UI.
enum PremiumPlan { monthly, yearly, lifetime }

PremiumPlan? premiumPlanFromId(String? id) {
  switch (id) {
    case 'monthly':
      return PremiumPlan.monthly;
    case 'yearly':
      return PremiumPlan.yearly;
    case 'lifetime':
      return PremiumPlan.lifetime;
  }
  return null;
}

extension PremiumPlanX on PremiumPlan {
  String get id {
    switch (this) {
      case PremiumPlan.monthly:
        return 'monthly';
      case PremiumPlan.yearly:
        return 'yearly';
      case PremiumPlan.lifetime:
        return 'lifetime';
    }
  }

  String get titleFa {
    switch (this) {
      case PremiumPlan.monthly:
        return 'ماهانه';
      case PremiumPlan.yearly:
        return 'سالانه';
      case PremiumPlan.lifetime:
        return 'همیشگی';
    }
  }
}

/// How the premium state was obtained.
enum EntitlementSource { none, rewardedAd, purchased, promo }

/// Premium entitlement. Never a bare boolean (product spec §33): the state
/// is owned by [EntitlementService] and persists independently of UI.
class Entitlement {
  const Entitlement({
    required this.source,
    this.plan,
    this.validUntil,
    this.rewardedUnlockDay,
    this.rewardedUnlockMonth,
  });

  const Entitlement.none()
      : source = EntitlementSource.none,
        plan = null,
        validUntil = null,
        rewardedUnlockDay = null,
        rewardedUnlockMonth = null;

  final EntitlementSource source;
  final PremiumPlan? plan;

  /// ISO date until which a purchase is valid (null = lifetime/none).
  final DateTime? validUntil;

  /// Day key ("1405-07-14") for which a rewarded ad unlocked full daily.
  final String? rewardedUnlockDay;

  /// Month key ("1405-07") for which a rewarded ad unlocked the monthly.
  final String? rewardedUnlockMonth;

  bool get hasPremium =>
      plan == PremiumPlan.lifetime ||
      (validUntil != null && validUntil!.isAfter(DateTime.now()));

  /// Full daily horoscope unlocked for the given day?
  bool unlocksDailyFor(String dayKey) =>
      hasPremium || rewardedUnlockDay == dayKey;

  /// Advanced monthly report unlocked for the given month?
  bool unlocksMonthFor(String monthKey) =>
      hasPremium || rewardedUnlockMonth == monthKey;
}
