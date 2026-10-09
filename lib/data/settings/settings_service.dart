import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entitlement/entitlement.dart';

enum ThemeModeSetting { dark, light, system }

/// App settings persisted in SharedPreferences (DataStore-equivalent for
/// simple flags — product spec §23).
class AppSettings {
  const AppSettings({
    this.onboardingCompleted = false,
    this.notificationsEnabled = false,
    this.notificationHour = 8,
    this.notificationMinute = 0,
    this.themeMode = ThemeModeSetting.dark,
    this.themeSkin = AppThemeSkin.velvet,
    this.entitlementJson,
  });

  final bool onboardingCompleted;
  final bool notificationsEnabled;
  final int notificationHour; // 0..23
  final int notificationMinute; // 0..59
  final ThemeModeSetting themeMode;

  /// Which dark palette («تمِ آسمان») to use when the mode resolves dark.
  final AppThemeSkin themeSkin;

  /// Serialized entitlement (owned by [EntitlementService]).
  final String? entitlementJson;

  AppSettings copyWith({
    bool? onboardingCompleted,
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
    ThemeModeSetting? themeMode,
    AppThemeSkin? themeSkin,
    String? entitlementJson,
  }) =>
      AppSettings(
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        notificationHour: notificationHour ?? this.notificationHour,
        notificationMinute: notificationMinute ?? this.notificationMinute,
        themeMode: themeMode ?? this.themeMode,
        themeSkin: themeSkin ?? this.themeSkin,
        entitlementJson: entitlementJson ?? this.entitlementJson,
      );
}

abstract class SettingsService {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
  Future<void> clear();
}

class SharedPreferencesSettingsService implements SettingsService {
  SharedPreferencesSettingsService(this._prefs);

  static const _kOnboarding = 'onboardingCompleted';
  static const _kNotifEnabled = 'notificationsEnabled';
  static const _kNotifHour = 'notificationHour';
  static const _kNotifMinute = 'notificationMinute';
  static const _kThemeMode = 'themeMode';
  static const _kThemeSkin = 'themeSkin';
  static const _kEntitlement = 'premiumEntitlement';

  final SharedPreferences _prefs;

  @override
  Future<AppSettings> load() async {
    final themeIndex = _prefs.getInt(_kThemeMode) ?? 0;
    // The skin key is newer than the mode key; when absent, default to
    // the classic midnight palette (the look every previous version had).
    // Main skin since v1.9.0: «شبِ مخملی». Users who explicitly picked a
    // skin keep it (their index was saved); everyone else meets the new
    // look. (Velvet is appended last in the enum → old indices stay valid.)
    final skinIndex =
        _prefs.getInt(_kThemeSkin) ?? AppThemeSkin.velvet.index;
    return AppSettings(
      onboardingCompleted: _prefs.getBool(_kOnboarding) ?? false,
      notificationsEnabled: _prefs.getBool(_kNotifEnabled) ?? false,
      notificationHour: (_prefs.getInt(_kNotifHour) ?? 8).clamp(0, 23),
      notificationMinute: (_prefs.getInt(_kNotifMinute) ?? 0).clamp(0, 59),
      themeMode: ThemeModeSetting.values[themeIndex.clamp(0, 2)],
      themeSkin:
          AppThemeSkin.values[skinIndex.clamp(0, AppThemeSkin.values.length - 1)],
      entitlementJson: _prefs.getString(_kEntitlement),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_kOnboarding, settings.onboardingCompleted);
    await _prefs.setBool(_kNotifEnabled, settings.notificationsEnabled);
    await _prefs.setInt(_kNotifHour, settings.notificationHour);
    await _prefs.setInt(_kNotifMinute, settings.notificationMinute);
    await _prefs.setInt(_kThemeMode, settings.themeMode.index);
    await _prefs.setInt(_kThemeSkin, settings.themeSkin.index);
    if (settings.entitlementJson != null) {
      await _prefs.setString(_kEntitlement, settings.entitlementJson!);
    } else {
      await _prefs.remove(_kEntitlement);
    }
  }

  @override
  Future<void> clear() => _prefs.clear();
}

/// Persists/loads [Entitlement] as opaque JSON (never a raw boolean).
class EntitlementCodec {
  const EntitlementCodec._();

  static String encode(Entitlement e) => jsonEncode({
        'source': e.source.index,
        'plan': e.plan?.id,
        'validUntil': e.validUntil?.toIso8601String(),
        'rewardedUnlockDay': e.rewardedUnlockDay,
        'rewardedUnlockMonth': e.rewardedUnlockMonth,
        'v': 1,
      });

  static Entitlement decode(String? json) {
    if (json == null || json.isEmpty) return const Entitlement.none();
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, Object?>) return const Entitlement.none();
      final sourceIndex = (map['source'] as num?)?.toInt() ?? 0;
      final source = EntitlementSource.values[
          sourceIndex.clamp(0, EntitlementSource.values.length - 1)];
      final plan = premiumPlanFromId(map['plan'] as String?);
      final validUntilRaw = map['validUntil'] as String?;
      final validUntil =
          validUntilRaw == null ? null : DateTime.tryParse(validUntilRaw);
      return Entitlement(
        source: source,
        plan: plan,
        validUntil: validUntil,
        rewardedUnlockDay: map['rewardedUnlockDay'] as String?,
        rewardedUnlockMonth: map['rewardedUnlockMonth'] as String?,
      );
    } catch (_) {
      // Corrupted local data never crashes the app (spec §36).
      return const Entitlement.none();
    }
  }
}
