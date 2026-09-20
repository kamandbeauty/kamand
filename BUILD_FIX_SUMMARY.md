# خلاصه فیکس بیلد و هنگ امضا - v1.0.5.3

## مشکل ۱: بیلد Fail می‌شد
بیلدهای release و debug در GitHub Actions با خطای زیر fail می‌شدند:
```
error • Undefined name 'bankCardListProvider' • lib/screens/settings/settings_screen.dart:289:22
error • Undefined name 'selectedBankCardProvider' • lib/screens/settings/settings_screen.dart:290:22
error • Undefined name 'supplierListProvider' • lib/screens/settings/settings_screen.dart:291:22
error • Undefined name 'expenseListProvider' • lib/screens/settings/settings_screen.dart:292:22
```

این خطاها در `settings_screen.dart` بعد از اضافه شدن قابلیت پشتیبان‌گیری و بازیابی (backup/restore) ایجاد شده بود که در آن `ref.invalidate` برای providerهای جدید اضافه شده بود ولی importهای مربوطه جا افتاده بود.

### فیکس بیلد
در فایل `lib/screens/settings/settings_screen.dart` سه import اضافه شد:
```dart
import '../../providers/bank_card_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/expense_provider.dart';
```
کامیت: `e436b80`

### نتایج بیلد v1.0.5.2
- Debug Build ران `35523841568`: `BUILD SUCCESSFUL in 4m 55s`
- Release Build ران `35524329515`: success با ۴ آرتیفکت ساین‌شده
- لینک: https://github.com/kamandbeauty/kamand/releases/tag/v1.0.5.2

---

## مشکل ۲: هنگ هنگام ذخیره عکس امضا (گزارش جدید کاربر)
> "وقتی عکس امضا را سیو میکنی صفحه خاکستری میشه و برنامه هنگ میکنه"

### ریشه مشکل
در `lib/core/utils/image_process_helper.dart`:
- پردازش سنگین تصویر (decode + crop + حذف پس‌زمینه سفید ۲ بار + resize) روی main thread انجام می‌شد
- `removeNearWhiteBackground` دو بار روی کل پیکسل‌ها loop می‌کرد (O(n) برای عکس‌های بزرگ)
- پاکسازی فایل‌های قدیمی با `listSync()` و `lastModifiedSync()` به صورت synchronous بود و UI را مسدود می‌کرد

در `lib/screens/customize/header_customize_screen.dart`:
- حذف فایل قدیمی با `existsSync()` و `deleteSync()` به صورت sync بود
- حالت `_saving` وجود نداشت و کاربر می‌توانست چند بار کلیک کند

در `lib/screens/customize/image_crop_screen.dart`:
- `_confirm()` بدون تایم‌اوت و بدون SnackBar لودینگ بود و اگر پردازش طولانی می‌شد، صفحه خاکستری می‌ماند

### فیکس هنگ امضا (v1.0.5.3)

#### 1. `image_process_helper.dart`
- پردازش سنگین به isolate منتقل شد با `compute(_processInIsolate, ...)`
- تایم‌اوت ۳۰ ثانیه اضافه شد
- fallback با maxSide کوچک‌تر (۵۰۰) در صورت fail
- `maxSide` از ۹۰۰ به ۷۰۰ کاهش یافت برای سرعت بیشتر
- پاکسازی فایل‌های قدیمی به صورت async و بدون مسدود کردن:
  ```dart
  static void _cleanupOldFilesAsync(...) {
    Future(() async {
      await for (final entity in folder.list()) { ... }
      final stat = await f.lastModified();
      await entry.key.delete();
    });
  }
  ```

#### 2. `header_customize_screen.dart`
- `tryDeleteOld` از sync به async تغییر کرد:
  ```dart
  Future<void> tryDeleteOldAsync(...) async {
    if (await f.exists()) await f.delete();
  }
  ```
- حذف فایل‌ها با `Future.wait` در background بدون await
- حالت `_saving` اضافه شد با CircularProgressIndicator
- دکمه ذخیره هنگام saving غیرفعال می‌شود

#### 3. `image_crop_screen.dart`
- SnackBar لودینگ با CircularProgressIndicator اضافه شد
- تایم‌اوت ۳۵ ثانیه برای `processAndSave`
- `hideCurrentSnackBar` در finally برای جلوگیری از خاکستری ماندن صفحه
- رنگ پس‌زمینه خطا به قرمز

کامیت: `79bcdc7` و `a2c3ca6`

### نتایج بیلد v1.0.5.3
- Debug Build ران `35530075369`: success
- Release Build ران `35530080561`: success با ۴ آرتیفکت ساین‌شده
- لینک: https://github.com/kamandbeauty/kamand/releases/tag/v1.0.5.3
- آرتیفکت‌ها:
  - `RubiFactor-v1.0.5-vc7-arm64-v8a-release.apk`
  - `RubiFactor-v1.0.5-vc7-armeabi-v7a-release.apk`
  - `RubiFactor-v1.0.5-vc7-x86_64-release.apk`
  - `RubiFactor-v1.0.5-vc7-release.aab`

---

## وضعیت ورکفلوها و سکرت‌ها

### Workflows
- `android-build.yml`: فقط روی branch `main`، سالم
- `release.yml`: روی تگ‌های `v*.*.*`، با v1.0.5.2 و v1.0.5.3 تست و موفق - سکرت‌های signing معتبر
- `debug-arena.yml`: ساده‌سازی شد، روی `arena/01a0bed4-kamand` با موفقیت پاس می‌شود

### Secrets
- `RELEASE_KEYSTORE_BASE64`: معتبر (Validate signing secrets success)
- `RELEASE_STORE_PASSWORD`: معتبر
- `RELEASE_KEY_ALIAS`: معتبر
- `RELEASE_KEY_PASSWORD`: معتبر

## نسخه نهایی
- `pubspec.yaml`: `1.0.5+7`
- تگ پایدار: `v1.0.5.3`
- آخرین کامیت: `a2c3ca6`

## تسک‌های قبلی (هنوز معتبر)
- Profit-only-in-reports: سود فقط در `accounting_summary_screen.dart`، نه در `invoice_preview_screen.dart` ✅
- تنظیمات فاکتور و پیش‌نمایش: فیکس‌های قبلی پابرجا ✅
- ورژن 1.0.5: zip/tar.gz در `dist/` ✅

