/// تنظیمات سراسری برنامه
library;

/// تنظیمات سرویس فال حافظ (one-api.ir)
class ApiConfig {
  ApiConfig._();

  /// توکن سرویس one-api.ir
  ///
  /// برای استفاده از توکن دیگر بدون تغییر سورس، هنگام اجرا
  /// مقدار را پاس بدهید:
  /// flutter run --dart-define=HAFEZ_API_TOKEN=xxxx:yyyy
  static const String hafezToken = String.fromEnvironment(
    'HAFEZ_API_TOKEN',
    defaultValue: '376746:653a7c0f1ea74',
  );

  /// آدرس پایهٔ سرویس
  static const String baseUrl = 'https://one-api.ir';

  /// دریافت یک فال تصادفی
  static Uri get hafezEndpoint =>
      Uri.parse('$baseUrl/hafez/?token=$hafezToken');

  /// آدرس سبک برای بررسی اتصال اینترنت
  static Uri get pingEndpoint => Uri.parse(baseUrl);
}

/// اطلاعات نسخهٔ برنامه
class AppInfo {
  AppInfo._();

  /// نسخه‌ای که داخل برنامه به کاربر نمایش داده می‌شود
  /// (هم‌خوان با version در pubspec.yaml)
  static const String version = '1.1';
}
