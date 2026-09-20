# خلاصه فیکس بیلد - v1.0.5.2

## مشکل اصلی
بیلدهای release و debug در GitHub Actions با خطای زیر fail می‌شدند:
```
error • Undefined name 'bankCardListProvider' • lib/screens/settings/settings_screen.dart:289:22
error • Undefined name 'selectedBankCardProvider' • lib/screens/settings/settings_screen.dart:290:22
error • Undefined name 'supplierListProvider' • lib/screens/settings/settings_screen.dart:291:22
error • Undefined name 'expenseListProvider' • lib/screens/settings/settings_screen.dart:292:22
```

این خطاها در `settings_screen.dart` بعد از اضافه شدن قابلیت پشتیبان‌گیری و بازیابی (backup/restore) ایجاد شده بود که در آن `ref.invalidate` برای providerهای جدید اضافه شده بود ولی importهای مربوطه جا افتاده بود.

## فیکس انجام شده
در فایل `lib/screens/settings/settings_screen.dart` سه import اضافه شد:
```dart
import '../../providers/bank_card_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/expense_provider.dart';
```

کامیت: `e436b80 fix: add missing provider imports in settings_screen.dart`

## نتایج بیلد

### Debug Build
- ران `35523841568` با موفقیت پاس شد: `BUILD SUCCESSFUL in 4m 55s`
- فایل `app-debug.apk` با موفقیت ساخته شد
- لاگ: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

### Release Build (Signed)
- تگ `v1.0.5.2` با موفقیت بیلد شد
- ران `35524329515` با موفقیت پاس شد:
  - `Build signed release APKs (split by ABI) success`
  - `Build signed release AAB success`
  - `Verify APK and AAB signatures success`
  - `Upload signed release artifacts success`
  - `Create GitHub Release for tag success`

### آرتیفکت‌های ریلیز v1.0.5.2
- `RubiFactor-v1.0.5-vc6-arm64-v8a-release.apk` (27.5 MB)
- `RubiFactor-v1.0.5-vc6-armeabi-v7a-release.apk` (25.4 MB)
- `RubiFactor-v1.0.5-vc6-x86_64-release.apk` (29.1 MB)
- `RubiFactor-v1.0.5-vc6-release.aab` (65 MB)

لینک: https://github.com/kamandbeauty/kamand/releases/tag/v1.0.5.2

## وضعیت ورکفلوها و سکرت‌ها

### Workflows
- `android-build.yml`: فقط روی branch `main` اجرا می‌شود، سالم است
- `release.yml`: روی تگ‌های `v*.*.*` اجرا می‌شود، با تگ v1.0.5.2 تست و موفق بود - سکرت‌های signing معتبر هستند
- `debug-arena.yml`: روی `arena/01a0bed4-kamand` اجرا می‌شود، ساده‌سازی شد و با موفقیت پاس می‌شود

### Secrets
- `RELEASE_KEYSTORE_BASE64`: معتبر (Validate signing secrets success)
- `RELEASE_STORE_PASSWORD`: معتبر
- `RELEASE_KEY_ALIAS`: معتبر
- `RELEASE_KEY_PASSWORD`: معتبر

همه سکرت‌ها در ران 35524329515 با موفقیت validate شدند.

## نسخه
- `pubspec.yaml`: `1.0.5+6` (از `1.0.5+5` به `1.0.5+6` ارتقا یافت)
- تگ: `v1.0.5.2`

## تسک‌های قبلی (هنوز معتبر)
- Profit-only-in-reports: سود فقط در `accounting_summary_screen.dart` نمایش داده می‌شود، نه در `invoice_preview_screen.dart` - بررسی و تایید شد
- تنظیمات فاکتور و پیش‌نمایش: فیکس‌های قبلی (bfbaef9) همچنان پابرجا
- ورژن 1.0.5: خروجی‌های zip/tar.gz در `dist/` موجود

## گام‌های بعدی
- می‌توان تگ `v1.0.5.2` را به عنوان نسخه پایدار در نظر گرفت
- برای انتشار نهایی، می‌توان PR از `arena/01a0bed4-kamand` به `main` ایجاد کرد
- فایل‌های debug issue (19-35) برای تمیزی می‌توانند بسته شوند (نیاز به دسترسی admin دارد)
