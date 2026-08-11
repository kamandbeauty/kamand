import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/business_profile_model.dart';
import '../../models/app_settings_model.dart';

/// ذخیره پایدار تنظیمات کاربر / کسب‌وکار / ظاهر روی گوشی
class PrefsStore {
  static const _kUser = 'ruby_user_v1';
  static const _kBusiness = 'ruby_business_v1';
  static const _kSettings = 'ruby_settings_v1';

  static Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  static Future<void> saveUser(UserModel u) async {
    final p = await _p;
    await p.setString(_kUser, jsonEncode(u.toMap()));
  }

  static Future<UserModel?> loadUser() async {
    final p = await _p;
    final s = p.getString(_kUser);
    if (s == null || s.isEmpty) return null;
    try {
      return UserModel.fromMap(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveBusiness(BusinessProfileModel b) async {
    final p = await _p;
    await p.setString(_kBusiness, jsonEncode(b.toMap()));
  }

  static Future<BusinessProfileModel?> loadBusiness() async {
    final p = await _p;
    final s = p.getString(_kBusiness);
    if (s == null || s.isEmpty) return null;
    try {
      return BusinessProfileModel.fromMap(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSettings(AppSettingsModel s) async {
    final p = await _p;
    await p.setString(_kSettings, jsonEncode(s.toMap()));
  }

  static Future<AppSettingsModel?> loadSettings() async {
    final p = await _p;
    final s = p.getString(_kSettings);
    if (s == null || s.isEmpty) return null;
    try {
      return AppSettingsModel.fromMap(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
