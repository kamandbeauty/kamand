import '../../domain/entitlement/entitlement.dart';

/// Built-in, offline promo codes (product decision: launch campaign).
///
/// Codes are validated locally — no network, no account. A redeemed code
/// grants the entitlement described by the campaign and is persisted the
/// same way purchases are (via EntitlementService → settings).
class PromoCode {
  const PromoCode({
    required this.code,
    required this.campaignFa,
    required this.plan,
    required this.percentOff,
  });

  /// Canonical code (uppercase latin + digits).
  final String code;

  /// Campaign label shown in the UI.
  final String campaignFa;

  /// Plan the code grants.
  final PremiumPlan plan;

  /// Campaign discount percentage (display only).
  final int percentOff;
}

class PromoCodes {
  PromoCodes._();

  /// Launch campaign: 100% off lifetime premium.
  static const PromoCode launch =
      PromoCode(
        code: 'TALEBIN1405',
        campaignFa: 'کمپین راه‌اندازیِ «طالع بین»',
        plan: PremiumPlan.lifetime,
        percentOff: 100,
      );

  static const List<PromoCode> all = [launch];

  /// Normalizes user input: trims, uppercases, drops spaces, dashes and
  /// Persian/Arabic digit variants so «talebin 1405» and «Talebin-1405»
  /// all match.
  static String normalize(String input) {
    final persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    final arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    final latinDigits = '0123456789';
    final buffer = StringBuffer();
    for (final rune in input.trim().runes) {
      var ch = String.fromCharCode(rune);
      final pi = persianDigits.indexOf(ch);
      if (pi >= 0) ch = latinDigits[pi];
      final ai = arabicDigits.indexOf(ch);
      if (ai >= 0) ch = latinDigits[ai];
      if (ch == ' ' || ch == '-' || ch == '_' || ch == '\u200c') continue;
      buffer.write(ch.toUpperCase());
    }
    return buffer.toString();
  }

  /// Looks the code up; null when unknown.
  static PromoCode? lookup(String input) {
    final normalized = normalize(input);
    for (final promo in all) {
      if (promo.code == normalized) return promo;
    }
    return null;
  }
}
