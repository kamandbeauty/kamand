/// Runtime configuration for account and Cafe Bazaar services.
///
/// Values are supplied at build time so service credentials and environment
/// URLs are never hard-coded in the application source:
///
/// flutter build apk \
///   --dart-define=AUTH_API_BASE_URL=https://api.example.com \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=... \
///   --dart-define=BAZAAR_RSA_PUBLIC_KEY=... \
///   --dart-define=BAZAAR_PREMIUM_PRODUCT_ID=ruby_premium_monthly
class ServiceConfig {
  static const authApiBaseUrl = String.fromEnvironment(
    'AUTH_API_BASE_URL',
  );
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const bazaarRsaPublicKey = String.fromEnvironment(
    'BAZAAR_RSA_PUBLIC_KEY',
  );
  static const bazaarPremiumProductId = String.fromEnvironment(
    'BAZAAR_PREMIUM_PRODUCT_ID',
  );

  static bool get hasAuthApi => authApiBaseUrl.trim().isNotEmpty;
  static bool get hasGoogleAuth =>
      hasAuthApi && googleServerClientId.trim().isNotEmpty;
  static bool get hasBazaarBilling =>
      hasAuthApi &&
      bazaarRsaPublicKey.trim().isNotEmpty &&
      bazaarPremiumProductId.trim().isNotEmpty;
}
