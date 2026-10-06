/// Minimal, privacy-safe analytics (product spec §34).
///
/// v1 is fully offline: events are kept local and debug-loggable. The
/// interface mirrors typical product-analytics events so a future backend
/// (opt-in, per privacy policy) can subscribe without touching call sites.
abstract class AnalyticsService {
  void logEvent(String name, [Map<String, Object?>? params]);
}

enum AnalyticsEvent {
  appOpen('app_open'),
  onboardingCompleted('onboarding_completed'),
  dailyHoroscopeOpened('daily_horoscope_opened'),
  weeklyHoroscopeOpened('weekly_horoscope_opened'),
  monthlyHoroscopeOpened('monthly_horoscope_opened'),
  compatibilityOpened('compatibility_opened'),
  coupleOpened('couple_opened'),
  partnerCreated('partner_created'),
  premiumScreenOpened('premium_screen_opened'),
  rewardedAdStarted('rewarded_ad_started'),
  settingsChanged('settings_changed');

  const AnalyticsEvent(this.id);
  final String id;
}

/// Local sink — no network, no PII, nothing leaves the device.
class LocalAnalyticsService implements AnalyticsService {
  final List<(String, DateTime)> _events = [];

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    assert(params == null || params.values.every((v) => v is String || v is int || v is bool),
        'analytics params must be primitive and non-sensitive');
    _events.add((name, DateTime.now()));
    if (_events.length > 500) {
      _events.removeRange(0, _events.length - 500);
    }
  }

  int get eventCount => _events.length;
}
