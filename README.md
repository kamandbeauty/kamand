# فاکتوریار (FactorYar)

[![Android Debug Build](https://github.com/kamandbeauty/kamand/actions/workflows/android-build.yml/badge.svg)](https://github.com/kamandbeauty/kamand/actions/workflows/android-build.yml)

اپلیکیشن اندرویدی صدور فاکتور، پیش‌فاکتور و فاکتور خرید + مدیریت مشتریان (CRM ساده) + مدیریت انبار و بارکد + ثبت هزینه و سود خالص + یادآوری بدهی + ویجت صفحه اصلی + خروجی PDF و تصویر + گزارش مالی.

طراحی‌شده برای بازار ایران (کافه‌بازار / مایکت). کاملاً آفلاین، **بدون وابستگی اجباری به Google Play Services**.

> ⚠️ **وضعیت پروژه:** کد کامل نوشته شده اما هنوز اولین بیلد موفق ثبت نشده است.
> برای دیدن آخرین وضعیت، تب [Actions](../../actions) را ببینید.

---

## دریافت APK آماده

**بدون نصب هیچ ابزاری** می‌توانید APK بگیرید:

1. به تب **[Actions](../../actions)** بروید
2. آخرین اجرای موفق **Android Debug Build** را باز کنید (تیک سبز ✅)
3. در پایین صفحه، بخش **Artifacts** → روی `factoryar-debug-apk` کلیک کنید
4. فایل ZIP دانلود می‌شود؛ داخلش `app-debug.apk` است

هر بار که کدی push شود، این APK به‌صورت خودکار بازسازی می‌شود.

---

## Build محلی

### پیش‌نیازها

| ابزار | نسخه | توضیح |
|---|---|---|
| JDK | **۱۷ تا ۲۳** | حداقل ۱۷ (الزام AGP 8.5) — حداکثر ۲۳ (سقف Gradle 8.10.2) |
| Android SDK | API 34 + Build-Tools 34.0.0 | |
| Gradle | لازم نیست | Wrapper در مخزن هست |

### دستور بیلد

```bash
./gradlew assembleDebug          # لینوکس / مک
.\gradlew.bat assembleDebug      # ویندوز
```

خروجی: `app/build/outputs/apk/debug/app-debug.apk`

دستورات دیگر:

```bash
./gradlew :app:installDebug      # نصب روی گوشی متصل
./gradlew test                   # تست‌های واحد
./gradlew :app:assembleRelease   # نسخه release
```

### مسیر SDK

فایل `local.properties` در ریشه بسازید:

```properties
sdk.dir=/home/<user>/Android/Sdk
# ویندوز: sdk.dir=C\:\\Users\\<user>\\AppData\\Local\\Android\\Sdk
```

---

## Build با GitHub Actions

دو workflow آماده است:

### ۱. `android-build.yml` — بیلد Debug

**اجرا:** روی هر push و pull request، یا دستی از تب Actions

**مراحل:** Checkout → JDK 17 → Gradle Cache → `assembleDebug` → آپلود APK

**خروجی:** artifact با نام `factoryar-debug-apk`

همچنین یک job جدا تست‌های واحد را اجرا می‌کند.

### ۲. `android-release.yml` — بیلد Release

**اجرا:** با push کردن tag (مثل `v1.0.0`) یا دستی

**خروجی‌ها:**
- `factoryar-release-apk` — برای کافه‌بازار و مایکت
- `factoryar-release-aab` — فرمت Google Play
- `factoryar-mapping` — فایل mapping برای رمزگشایی crash

هنگام push کردن tag، یک **GitHub Release پیش‌نویس** هم ساخته می‌شود.

### تنظیم کلید امضا (برای Release)

کلید امضا **هرگز داخل مخزن قرار نمی‌گیرد**. از GitHub Secrets استفاده کنید:

`Settings → Secrets and variables → Actions → New repository secret`

| Secret | توضیح |
|---|---|
| `KEYSTORE_BASE64` | محتوای فایل keystore به Base64 |
| `KEYSTORE_PASSWORD` | رمز فایل keystore |
| `KEY_ALIAS` | نام alias کلید |
| `KEY_PASSWORD` | رمز کلید |

ساخت keystore و مقدار Base64:

```bash
# ساخت کلید (یک‌بار)
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias factoryar

# تبدیل به Base64
base64 -w 0 release.jks           # لینوکس/مک
```

```powershell
# ویندوز
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.jks")) | Set-Clipboard
```

> اگر Secrets تنظیم نشده باشد، بیلد release با امضای debug انجام می‌شود تا
> صحت کامپایل بررسی شود — آن خروجی **قابل انتشار نیست**.

برای امضای محلی، فایل `keystore.properties` بسازید (در `.gitignore` است):

```properties
storeFile=/path/to/release.jks
storePassword=***
keyAlias=factoryar
keyPassword=***
```

---

## ساختار پروژه

معماری **MVVM + Clean Architecture** چندماژوله. جزئیات کامل در [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

```
app/                    پوسته اپ، ناوبری، Workerها، ویجت Glance
├── core/
│   ├── common/         تقویم جلالی، فرمت‌دهی فارسی        (JVM خالص)
│   ├── domain/         مدل‌ها، Repository interface، UseCase (JVM خالص)
│   ├── database/       Room: Entity / DAO / Migration
│   ├── datastore/      تنظیمات (تم، شماره‌گذاری، چاپگر)
│   ├── data/           پیاده‌سازی Repository، کلید SQLCipher، Hilt
│   ├── ui/             موتور تم M3، کامپوننت‌ها، نمودارها
│   ├── pdf/            تولید خروجی PDF و تصویر (JPG) فاکتور و گزارش
│   ├── billing/        Poolakey — اشتراک طلایی
│   └── barcode/        اسکن بارکد (CameraX + ML Kit ← ZXing ← دستی)
└── feature/
    ├── dashboard/  invoices/  customers/
    ├── reports/    products/  expenses/  settings/
```

**قانون وابستگی:** featureها فقط به `core:domain` و `core:ui` وابسته‌اند. لایهٔ داده از طریق Hilt تزریق می‌شود، پس افزودن بک‌اند سروری در فاز ۲ فقط نیازمند یک پیاده‌سازی جدید از Repository است.

### فناوری‌ها

Kotlin • Jetpack Compose (بدون XML) • Room + SQLCipher • Hilt • WorkManager • DataStore • Glance • CameraX + ML Kit (bundled، بدون GMS) • PdfDocument + PdfRenderer • Poolakey

---

## قابلیت‌ها (نسخه رایگان)

- فاکتور فروش / پیش‌فاکتور / فاکتور خرید با اقلام نامحدود، تخفیف و مالیات
- CRM: دفتر حساب مشتری، سابقه خرید، مانده بدهی
- **انبار و بارکد:** موجودی، حد هشدار، قیمت عمده/خرده، بهای تمام‌شده، کسر خودکار موجودی
- **هزینه‌ها و سود واقعی:** سود ناخالص و خالص + نمودار مقایسه‌ای
- **یادآوری بدهی:** شناسایی معوقات، متن آماده، ارسال با Share Intent
- **ویجت صفحه اصلی:** فروش امروز، تعداد معوق، میان‌بر فاکتور جدید
- **خروجی PDF و تصویر (JPG)** با اشتراک‌گذاری در تلگرام/واتساپ/ایمیل، فاکتور دوره‌ای، ۵ تم، CSV

**اشتراک طلایی:** گزارش PDF حرفه‌ای، انتخابگر رنگ آزاد، حذف واترمارک، پشتیبان‌گیری ابری، چند کسب‌وکار

---

## بیلد داخل ایران (تحریم و فیلترینگ)

Workflowهای CI از مخازن رسمی استفاده می‌کنند. برای بیلد محلی داخل ایران،
`settings.gradle.kts` به‌صورت خودکار تشخیص می‌دهد و میرورهای داخلی
(مایکت، en-mirror، کارگادان) را در اولویت قرار می‌دهد.

### اگر توزیع Gradle دانلود نشد

در `gradle/wrapper/gradle-wrapper.properties` خط `distributionUrl` را به میرور مایکت تغییر دهید:

```properties
distributionUrl=https\://maven.myket.ir/gradle/distributions/gradle-8.10.2-bin.zip
```

یا اگر Gradle از قبل نصب دارید: `gradle wrapper --gradle-version 8.10.2`

### اگر Android SDK نصب نیست

`dl.google.com` در ایران مسدود است. اسکریپت‌های کمکی:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup-sdk-windows.ps1   # ویندوز
```

```bash
bash scripts/fetch-android-sdk.sh      # لینوکس / مک
```

راهنمای کامل: [`docs/ANDROID_SDK_SETUP.md`](docs/ANDROID_SDK_SETUP.md)

### اگر خطای نسخهٔ جاوا گرفتید

```powershell
powershell -ExecutionPolicy Bypass -File scripts\set-jdk.ps1
```

| خطا | معنی |
|---|---|
| `This build uses a Java 8 JVM` | جاوا خیلی قدیمی — حداقل ۱۷ لازم است |
| خطای مبهم مثل `25.0.4` | جاوا خیلی جدید — حداکثر ۲۳ برای Gradle 8.10.2 |

---

## کارهای باقی‌مانده قبل از انتشار

- [ ] اولین بیلد موفق و رفع خطاهای کامپایل
- [ ] کلید RSA بازار در `BillingManager.kt` و ساخت SKUها (`factoryar_gold_monthly` / `_yearly`)
- [ ] فونت وزیرمتن در `core/ui/src/main/res/font/` و اتصال `FyFontFamily`
- [ ] تنظیم Secrets امضا در گیت‌هاب
- [ ] تست روی دستگاه بدون Google Play Services
- [ ] بررسی حجم APK (هدف: زیر ۱۵ مگابایت)

## نقشه راه فاز ۲

- درگاه پرداخت آنلاین ایرانی برای لینک پرداخت فاکتور
- بک‌اند همگام‌سازی چنددستگاهی
- اتصال به MPOS با پرداخت کارتی
