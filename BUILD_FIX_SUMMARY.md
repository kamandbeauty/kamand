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

## مشکل ۳: گزارش سود اشتباه + سازگاری اندروید ۱۴/۱۵/۱۶ (v1.0.7)

### باگ سود (اسکرین‌شات کاربر 2026-09-20-23-32-56)
- فروش کل 81M، خرید کل 40.5M ولی "مجموع خرید کالاها (بهای تمام شده) 0" و "سود ناخالص 81M" نمایش داده می‌شد
- ریشه: `InvoiceItemModel.totalBuyPrice = buyPrice*quantity` و `totalProfit = (unitPrice-buyPrice)*quantity`
- ولی در `dashboard_screen.dart` ردیف جدید با `buyPrice=0` ساخته می‌شد و اگر محصول از کاتالوگ انتخاب نمی‌شد، buyPrice صفر می‌ماند
- در نتیجه `totalBuyAmount=0` و `profitAmount=totalAmount` و گزارش سود اشتباه

#### فیکس سود
1. `dashboard_screen.dart`:
   - `_totalBuyAmount` و `_totalProfit` حالا از کاتالوگ lookup می‌کنند:
     ```dart
     final productMap = {for (var p in products) p.id: p, for (var p in products) p.name: p};
     if (buyPrice <= 0 && productMap.containsKey(productId)) buyPrice = productMap[productId]!.buyPrice;
     ```
   - `_updateItem`: وقتی عنوان تغییر می‌کند از کاتالوگ buyPrice پیدا می‌کند
   - `_saveInvoice`: `fixedItems` با buyPrice تصحیح شده از کاتالوگ، totalBuy و totalProfit دقیق

2. `accounting_summary_screen.dart`:
   - محاسبه دوباره بهای تمام شده از کاتالوگ اگر buyPrice صفر بود
   - اگر هنوز totalBuy صفر و فروش >0، هشدار زرد: "بهای تمام شده کالاها ثبت نشده! قیمت خرید را در کاتالوگ ثبت کنید"
   - فیلتر دوره: همه، ماه جاری، ماه قبل، سال جاری
   - گزارش ماهیانه: فروش، خرید، سود، هزینه به تفکیک ماه شمسی
   - کارت حساب تامین‌کنندگان در گزارش + صفحه جزئیات `SupplierDetailScreen`
   - `SupplierDetailScreen`: خرید کل، پرداخت شده، مانده، لیست فاکتورها، هزینه‌های مرتبط، وضعیت بدهکار/تسویه

3. `supplier_list_screen.dart`:
   - Tap روی تامین‌کننده → باز کردن کارت حساب
   - فیکس syntax error: `if (balance>0) Text else Text` → ternary

### باگ سازگاری اندروید (اسکرین‌شات 2026-09-20-21-41-22)
> "This app isn't compatible with the latest version of Android"

ریشه: اندروید 15+ دستگاه‌های 16KB page size را enforce می‌کند. اپ با NDK قدیمی و targetSdk پایین بیلد شده بود و کتابخانه‌های native (sqlite3) با 16KB سازگار نبودند.

#### فیکس اندروید 16KB
1. `android/app/build.gradle.kts`:
   ```kotlin
   compileSdk = 36
   ndkVersion = "28.0.13004108"
   targetSdk = 36
   minSdk = 21
   packaging { jniLibs { useLegacyPackaging = false } }
   ```

2. `android/gradle.properties`:
   ```
   android.experimental.enable16kPageSize=true
   android.nonTransitiveRClass=true
   ```

3. `pubspec.yaml`:
   ```yaml
   sqlite3: ^2.9.0
   sqlite3_flutter_libs: ^0.5.39  # 16KB support
   version: 1.0.7+9
   ```

- AGP 8.11.1 و Kotlin 2.2.20 قبلاً از 16KB پشتیبانی می‌کردند
- sqlite3_flutter_libs 0.5.39+ شامل .soهای 16KB-aligned است

### نتایج بیلد v1.0.7
- Debug Build ران `35534979491`: success in 5m4s
- Release Build ران `35535270757`: success in 8m31s با ۴ آرتیفکت ساین‌شده
- لینک: https://github.com/kamandbeauty/kamand/releases/tag/v1.0.7
- آرتیفکت‌ها:
  - `RubiFactor-v1.0.7-vc9-arm64-v8a-release.apk` (27.6 MB)
  - `RubiFactor-v1.0.7-vc9-armeabi-v7a-release.apk` (25.5 MB)
  - `RubiFactor-v1.0.7-vc9-x86_64-release.apk` (29.1 MB)
  - `RubiFactor-v1.0.7-vc9-release.aab` (65.3 MB)

## نسخه نهایی
- `pubspec.yaml`: `1.0.7+9`
- تگ پایدار: `v1.0.7`
- آخرین کامیت: `d2251d9`
- Android: compileSdk 36, targetSdk 36, NDK 28, 16KB page size support ✅
- Profit fix: بهای تمام شده و سود ناخالص دقیق با lookup از کاتالوگ ✅
- گزارش ماهیانه: فروش، خرید، سود، هزینه به تفکیک ماه ✅
- کارت حساب تامین‌کننده: SupplierDetailScreen با خرید کل، پرداخت، مانده، فاکتورها ✅

## تسک‌های قبلی (هنوز معتبر)
- Profit-only-in-reports: سود فقط در `accounting_summary_screen.dart`، نه در `invoice_preview_screen.dart` ✅
- تنظیمات فاکتور و پیش‌نمایش: فیکس‌های قبلی پابرجا ✅
- ورژن 1.0.5: zip/tar.gz در `dist/` ✅

