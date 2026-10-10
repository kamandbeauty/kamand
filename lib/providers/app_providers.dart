import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/business_profile_model.dart';
import '../models/app_settings_model.dart';
import '../core/utils/prefs_store.dart';

final userProvider = StateNotifierProvider<UserNotifier, UserModel>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<UserModel> {
  late final Future<void> _hydrated;

  UserNotifier()
      : super(UserModel(
          id: 'u1',
          name: '',
          phone: '',
          country: '',
          province: '',
          city: '',
          usageType: '',
          isOnboarded: false,
        )) {
    _hydrated = _hydrate();
  }

  Future<void> _hydrate() async {
    final saved = await PrefsStore.loadUser();
    if (saved != null) state = saved;
  }

  Future<void> updateUser(UserModel user) async {
    await _hydrated;
    state = user;
    await PrefsStore.saveUser(user);
  }
}

final businessProvider =
    StateNotifierProvider<BusinessNotifier, BusinessProfileModel>((ref) {
  return BusinessNotifier();
});

class BusinessNotifier extends StateNotifier<BusinessProfileModel> {
  late final Future<void> _hydrated;

  BusinessNotifier()
      : super(BusinessProfileModel(
          id: 'b1',
          shopName: '',
          phone: '',
          address: '',
          taxId: '',
          logoPath: '',
          stampPath: '',
          signaturePath: '',
          bankCards: const [],
        )) {
    _hydrated = _hydrate();
  }

  Future<void> _hydrate() async {
    final saved = await PrefsStore.loadBusiness();
    if (saved != null) state = saved;
  }

  Future<void> updateBusiness(BusinessProfileModel business) async {
    await _hydrated;
    state = business;
    await PrefsStore.saveBusiness(business);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettingsModel>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettingsModel> {
  late final Future<void> _hydrated;

  SettingsNotifier()
      : super(AppSettingsModel(
          startingInvoiceNum: 1,
          templateStyle: 'modern',
          showLogo: true,
          showCardNum: true,
          showStamp: true,
          showSignature: true,
          themeMode: 'light',
          autoBackup: true,
          pinCode: '',
          pinEnabled: false,
          accentColor: 0xFFF97316,
        )) {
    _hydrated = _hydrate();
  }

  Future<void> _hydrate() async {
    final saved = await PrefsStore.loadSettings();
    if (saved != null) state = saved;
  }

  Future<void> updateSettings(AppSettingsModel settings) async {
    await _hydrated;
    state = settings;
    await PrefsStore.saveSettings(settings);
  }

  /// Updates only invoice visibility flags using the latest hydrated state.
  /// This prevents a quick toggle during startup from overwriting unrelated
  /// settings with the notifier's temporary defaults.
  Future<void> updateInvoiceVisibility({
    bool? showStamp,
    bool? showCardNum,
  }) async {
    await _hydrated;
    final previous = state;
    final updated = previous.copyWith(
      showStamp: showStamp,
      showSignature: showStamp,
      showCardNum: showCardNum,
    );
    state = updated;
    try {
      await PrefsStore.saveSettings(updated);
    } catch (_) {
      // Keep the visible checkbox consistent with persisted data when storage
      // fails instead of showing a change that will disappear after restart.
      state = previous;
      rethrow;
    }
  }
}
