# فروشیار (ForushYar)

دستیار ساده و **آفلاین** برای فروشندگان اینستاگرامی جهت مدیریت مشتری، محصول، سفارش و سود.

- **زبان:** Kotlin
- **معماری:** MVVM
- **UI:** Jetpack Compose (Material 3)
- **Database:** Room (تماماً آفلاین)
- **DI:** Hilt
- **Async:** Kotlin Coroutines + Flow
- **Navigation:** Navigation Compose (Bottom Navigation ۵ تب)
- **Min SDK:** 26 (اندروید 8) · Target/Compile: 34

> کاملاً Offline First — بدون اینترنت، سرور، API، ثبت‌نام یا لاگین. تمام داده‌ها در حافظه داخلی گوشی ذخیره می‌شود.

## وضعیت فعلی (MVP کامل تا فاز ۸)

- [x] اسکلت کامل پروژه (Gradle, Manifest, Theme, Navigation, Hilt, DI)
- [x] مدل داده کامل: `customers` ،`products` ،`orders` ،`order_items`
- [x] صفحه داشبورد: فروش امروز، سود امروز، سفارش‌های باز، تعداد مشتری‌ها، آخرین سفارش‌ها
- [x] مدیریت مشتری‌ها: افزودن، ویرایش، حذف، جست‌وجو، جزئیات و تاریخچه سفارش‌ها
- [x] مدیریت محصولات: افزودن، ویرایش، حذف، جست‌وجو، قیمت‌ها و موجودی
- [x] مدیریت سفارش‌ها: ثبت چندقلمی، قیمت لحظه‌ای، جزئیات، وضعیت، سود و حذف
- [x] گزارش‌های امروز و ماه جاری شمسی: فروش، سود و تعداد سفارش‌ها
- [x] پیام آماده و شخصی‌سازی‌شده واتساپ از صفحه سفارش
- [x] خروجی و بازیابی کامل JSON با هشدار و اعتبارسنجی
- [x] تنظیمات نام فروشگاه، تأیید حذف و درباره برنامه
- [x] بیلد خودکار Debug و Release در GitHub Actions
- [x] زبان فارسی + جهت RTL + تقویم شمسی + اعداد فارسی

امکانات اصلی MVP کامل شده‌اند. جزئیات انتشار و نقشه راه در فایل `docs/PLAN.md` قرار دارد.

## پشتیبان‌گیری و حریم خصوصی

از تب «تنظیمات» می‌توان تمام مشتری‌ها، محصولات، سفارش‌ها و تنظیمات را در فایل
`ForushYar_Backup_YYYY-MM-DD.json` ذخیره کرد. بازیابی فقط پس از نمایش هشدار انجام می‌شود و
اطلاعات فعلی را در یک تراکنش امن Room جایگزین می‌کند. برنامه مجوز اینترنت ندارد و Android Cloud
Backup نیز غیرفعال است. متن سیاست حریم خصوصی در `docs/PRIVACY_POLICY_FA.md` قرار دارد.

## Build محلی بدون Android Studio

پیش‌نیازها: **JDK 17** و **Android SDK Platform 34** با متغیر `ANDROID_HOME` یا فایل
`local.properties`. پروژه Gradle Wrapper کامل دارد و نصب سراسری Gradle لازم نیست.

```bash
chmod +x gradlew
./gradlew assembleDebug
```

خروجی Debug در مسیر زیر ساخته می‌شود:

```text
app/build/outputs/apk/debug/app-debug.apk
```

برای ساخت خروجی Release بدون امضا می‌توان از `./gradlew assembleRelease bundleRelease` استفاده کرد.
نسخه قابل انتشار باید با کلید امن و ثابت فروشگاه امضا شود.

## Build خودکار با GitHub Actions

Workflow فایل `.github/workflows/android-build.yml` با هر Push به `main` یا شاخه‌های `arena/**`
و همچنین هر Pull Request اجرا می‌شود. این Workflow روی `ubuntu-latest`، با JDK 17 و Gradle Cache:

1. Gradle Wrapper را اعتبارسنجی می‌کند.
2. وابستگی‌ها را از مخزن‌های استاندارد دریافت می‌کند.
3. دستور `./gradlew assembleDebug` را اجرا می‌کند.
4. فایل‌های `app/build/outputs/apk/debug/*.apk` را به‌عنوان Artifact ذخیره می‌کند.

### دریافت APK از GitHub

در صفحه مخزن وارد **Actions** شوید، آخرین اجرای موفق «بیلد خودکار نسخه Debug» را باز کنید و
از بخش **Artifacts** فایل `forushyar-debug-*` را دانلود کنید. برای این کار Android Studio لازم نیست.

## Release و امضای امن

Workflow جداگانه `.github/workflows/android-release.yml` با اجرای دستی یا Push کردن Tagهایی مانند
`v1.0.0`، هر دو خروجی `APK` و `AAB` را می‌سازد. کلید امضا نباید وارد Git شود. چهار Secret زیر را در
`Settings → Secrets and variables → Actions` تعریف کنید:

| Secret | توضیح |
|---|---|
| `KEYSTORE_FILE` | محتوای Base64 فایل JKS |
| `KEYSTORE_PASSWORD` | رمز Keystore |
| `KEY_ALIAS` | نام Alias کلید |
| `KEY_PASSWORD` | رمز کلید |

تبدیل فایل Keystore به Base64 در Linux/macOS:

```bash
base64 -w 0 forushyar-release.jks
```

در macOS در صورت پشتیبانی‌نشدن گزینه بالا از `base64 < forushyar-release.jks | tr -d '\n'` استفاده کنید.
خروجی Release از بخش Artifacts همان اجرای Workflow قابل دریافت است. فایل‌های `*.jks` و
`*.keystore` نیز در `.gitignore` قرار دارند.

## نکته برای کاربران ایران (آینه/میرور)

اگر دریافت وابستگی‌ها از مخزن‌های پیش‌فرض برای شما کند یا مسدود است، می‌توانید از طریق
یک فایل `init.gradle` آینه‌ی ایرانی را اضافه کنید. یک نمونه آماده به‌نام `init.gradle.example`
در ریشه پروژه قرار دارد. تنظیمات اصلی فقط از `google()`، `mavenCentral()` و
`gradlePluginPortal()` استفاده می‌کنند تا GitHub Actions بدون تنظیم اختصاصی Build شود.

## ساختار

```
app/src/main/java/com/forushyar/app/
├── ForushYarApplication.kt     # فعال‌سازی Hilt + زبان فارسی
├── MainActivity.kt
├── core/LocaleManager.kt       # اجبار RTL / فارسی
├── data/
│   ├── local/                  # AppDatabase + entity + dao
│   └── repository/             # Customer / Product / Order / Dashboard
├── di/DatabaseModule.kt        # Hilt
├── ui/{theme,navigation,home,customers,products,orders,settings,common}
└── util/                       # تاریخ، اعداد و راه‌انداز واتساپ
```

جزئیات کامل معماری، دیاگرام دیتابیس، لیست وابستگی‌ها و نقشه راه در [docs/PLAN.md](docs/PLAN.md).

## وابستگی‌ها

AGP 8.5.2 · Kotlin 2.0.21 · Compose BOM 2024.09.02 · Navigation 2.7.7 · Hilt 2.52 · Room 2.6.1 · Coroutines 1.8.1
