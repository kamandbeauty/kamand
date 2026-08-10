import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/business_profile_model.dart';
import '../models/app_settings_model.dart';

final userProvider = StateNotifierProvider<UserNotifier, UserModel>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<UserModel> {
  UserNotifier()
      : super(UserModel(
          id: 'u1',
          name: 'علی علوی',
          country: 'ایران',
          province: 'تهران',
          city: 'تهران',
          usageType: 'store',
          isOnboarded: true,
        ));

  void updateUser(UserModel user) {
    state = user;
  }
}

final businessProvider =
    StateNotifierProvider<BusinessNotifier, BusinessProfileModel>((ref) {
  return BusinessNotifier();
});

class BusinessNotifier extends StateNotifier<BusinessProfileModel> {
  BusinessNotifier()
      : super(BusinessProfileModel(
          id: 'b1',
          shopName: 'فروشگاه آنلاین روبی',
          phone: '۰۲۱-۸۸۸۸۹۹۹۹',
          address: 'تهران، خیابان ولیعصر، پلاک ۱۲۴',
          taxId: '۱۰۱۰۹۸۷۶۵۴۳',
          logoPath: '',
          bankCards: ['6037-9975-1234-5678', '5022-2910-8765-4321'],
        ));

  void updateBusiness(BusinessProfileModel b) {
    state = b;
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettingsModel>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettingsModel> {
  SettingsNotifier()
      : super(AppSettingsModel(
          startingInvoiceNum: 1004,
          templateStyle: 'modern',
          showLogo: true,
          showCardNum: true,
          themeMode: 'light',
          autoBackup: true,
          pinCode: '',
          pinEnabled: false,
        ));

  void updateSettings(AppSettingsModel s) {
    state = s;
  }
}
