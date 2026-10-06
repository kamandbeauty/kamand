class PrivacySettings {
  const PrivacySettings({
    required this.analyticsEnabled,
    required this.personalizedAdsEnabled,
    required this.contentUpdatesEnabled,
  });

  final bool analyticsEnabled;
  final bool personalizedAdsEnabled;
  final bool contentUpdatesEnabled;

  static const defaults = PrivacySettings(
    analyticsEnabled: false,
    personalizedAdsEnabled: false,
    contentUpdatesEnabled: true,
  );

  PrivacySettings copyWith({
    bool? analyticsEnabled,
    bool? personalizedAdsEnabled,
    bool? contentUpdatesEnabled,
  }) {
    return PrivacySettings(
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      personalizedAdsEnabled: personalizedAdsEnabled ?? this.personalizedAdsEnabled,
      contentUpdatesEnabled: contentUpdatesEnabled ?? this.contentUpdatesEnabled,
    );
  }
}
