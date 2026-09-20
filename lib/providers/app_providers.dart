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

  Future<void> ensureLoaded() => _hydrated;

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

  Future<void> ensureLoaded() => _hydrated;

  Future<void> _hydrate() async {
    final saved = await PrefsStore.loadBusiness();
    if (saved != null) state = saved;
  }

  Future<void> updateBusiness(BusinessProfileModel b) async {
    await _hydrated;
    state = b;
    await PrefsStore.saveBusiness(b);
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

  Future<void> ensureLoaded() => _hydrated;

  Future<void> _hydrate() async {
    final saved = await PrefsStore.loadSettings();
    if (saved != null) state = saved;
  }

  Future<void> updateSettings(AppSettingsModel s) async {
    await _hydrated;
    state = s;
    await PrefsStore.saveSettings(s);
  }
}
