# فروشیار (ForushYar) — سند طراحی و نقشه راه نسخه اول (MVP)

> دستیار آفلاین فروشندگان اینستاگرامی: مدیریت مشتری، محصول، سفارش و سود.

## 1) خلاصه

یک اپلیکیشن **Native Android** با **Kotlin + Jetpack Compose + Room + Hilt**، کاملاً **Offline First**.
هیچ وابستگی به اینترنت، سرور، API، ثبت‌نام یا لاگین ندارد. تمام داده‌ها روی حافظه داخلی گوشی و در
**Room Database** ذخیره می‌شود. هدف: انتشار در **کافه‌بازار** و **مایکت**.

## 2) معماری فایل‌ها (MVVM)

```
app/src/main/java/com/forushyar/app/
├── ForushYarApplication.kt      # نقطه شروع، فعال‌سازی Hilt و زبان فارسی
├── MainActivity.kt              # اکتیویتی اصلی + اتصال به Compose
│
├── core/
│   └── LocaleManager.kt         # اجبار زبان فارسی و جهت RTL
│
├── data/
│   ├── local/
│   │   ├── AppDatabase.kt       # کلاس Room Database
│   │   ├── dao/                 # CustomerDao / ProductDao / OrderDao / OrderItemDao
│   │   └── entity/              # Customer / Product / Order / OrderItem / Relations / OrderStatus
│   └── repository/              # Customer / Product / Order / Dashboard
│
├── di/
│   └── DatabaseModule.kt        # ماژول Hilt برای ارائه Database و DAOها
│
├── ui/
│   ├── theme/                   # Color / Type / Theme (Material 3)
│   ├── navigation/              # BottomNavItem / AppNavGraph
│   ├── home/                    # HomeScreen + HomeViewModel (داشبورد)
│   ├── customers/               # فهرست، فرم و جزئیات/تاریخچه مشتری
│   ├── products/                # فهرست، فرم و جزئیات/موجودی محصول
│   ├── orders/                  # ثبت، فهرست، جزئیات و وضعیت سفارش
│   ├── settings/                # تنظیمات، پشتیبان‌گیری و درباره برنامه
│   └── common/                  # اجزای مشترک
│
└── util/
    ├── DateUtils.kt             # بازه امروز، تاریخ
    └── FormatUtils.kt           # اعداد/مبلغ فارسی + تقویم شمسی
```

**جریان داده:** `Room (Flow)` ← `Repository` ← `ViewModel (StateFlow)` ← `Compose (collectAsStateWithLifecycle)`.
پایگاه داده تنها منبع حقیقت است؛ UI با هر تغییر داده به‌صورت خودکار به‌روز می‌شود (Reactive).

## 3) Database Schema

| جدول | فیلدها | رابطه |
|------|--------|-------|
| `customers` | id, name, phone, instagramId, address, note, createdDate | — |
| `products` | id, name, category, buyPrice, sellPrice, stock, createdDate | — |
| `orders` | id, customerId, status, createdAt, note | ۱:N → customers (CASCADE) |
| `order_items` | id, orderId, productId, quantity, buyPrice, sellPrice | ۱:N → orders (CASCADE) |

```
Customer 1 ────< Order 1 ────< OrderItem >──── Product (1)
```

- `order_items` قیمت خرید/فروش را در لحظه ثبت «عکس» می‌گیرد تا تغییر قیمت محصول به سفارش‌های گذشته آسیب نزند.
- سود هر قلم = `(sellPrice - buyPrice) × quantity`.
- وضعیت سفارش: `NEW → PREPARING → SENT → DELIVERED | CANCELLED`.

## 4) Dependency List

| کتابخانه | نسخه | کاربرد |
|----------|------|--------|
| Android Gradle Plugin | 8.5.2 | بیلد اندروید |
| Kotlin | 2.0.21 | زبان |
| Compose BOM | 2024.09.02 | Jetpack Compose (Material 3) |
| Navigation Compose | 2.7.7 | ناوبری |
| Hilt | 2.52 | تزریق وابستگی |
| Room | 2.6.1 | پایگاه داده |
| Coroutines / Flow | 1.8.1 | برنامه‌نویسی ناهمگام |
| Lifecycle (runtime/viewmodel/compose) | 2.8.6 | چرخه حیات |

- **SDK:** minSdk 26 (اندروید 8) · compile/target 34
- **Replicability:** فقط از `google()` و `mavenCentral()` استفاده شده (قابل دریافت با آینه‌های رایج ایران از طریق `init.gradle`).
- **بدون** کتابخانه سنگین و غیرضروری؛ بدون اینترنت‌محور بودن.

## 5) Roadmap

| فاز | محتوا | وضعیت |
|-----|-------|-------|
| ۱ | اسکلت پروژه + دیتابیس + صفحه داشبورد | ✅ انجام شد |
| ۲ | مدیریت مشتری‌ها (افزودن/ویرایش/حذف/جست‌وجو/تاریخچه) | ✅ انجام شد |
| ۳ | مدیریت محصولات (افزودن/ویرایش/حذف/جست‌وجو/موجودی) | ✅ انجام شد |
| ۴ | مدیریت سفارش‌ها (ثبت/وضعیت/جزئیات/حذف) | ✅ انجام شد |
| ۵ | گزارش‌های ساده (امروز/این ماه شمسی/سود/تعداد سفارش) | ✅ انجام شد |
| ۶ | پیام آماده واتساپ | ✅ انجام شد |
| ۷ | سیستم Backup (Export/Import JSON) | ✅ انجام شد |
| ۸ | تنظیمات (نام فروشگاه/تأیید حذف/درباره) | ✅ انجام شد |
| ۹ | تست، آماده‌سازی و انتشار (کافه‌بازار و مایکت) | در حال نهایی‌سازی |

> **خارج از محدوده MVP:** سیستم چندکاربره، پنل مدیریت، سرور، API، اتصال اینستاگرام، پرداخت آنلاین، چت داخلی، حسابداری و انبارداری پیچیده.

## 6) وضعیت فعلی پیاده‌سازی

- اسکلت کامل پروژه (Gradle, Manifest, Theme, Navigation, Hilt, DI)
- مدل داده کامل (۴ جدول + روابط + DAOها + Repositoryها)
- صفحه داشبورد: فروش امروز، سود امروز، سفارش‌های باز، تعداد مشتری‌ها، آخرین سفارش‌ها
- مدیریت مشتری‌ها: فهرست و جست‌وجوی لحظه‌ای، ثبت، ویرایش، حذف امن و مشاهده تاریخچه سفارش‌ها
- مدیریت محصولات: فهرست و جست‌وجوی لحظه‌ای، ثبت، ویرایش، حذف، قیمت خرید/فروش و موجودی
- مدیریت سفارش‌ها: ثبت چندقلمی، انتخاب مشتری/محصول، قیمت لحظه‌ای، محاسبه سود، وضعیت، جزئیات و حذف
- گزارش‌های واکنش‌گرا: فروش و سود امروز، فروش و سود ماه جاری شمسی و تعداد سفارش‌های ماه
- پیام آماده شخصی‌سازی‌شده و بازکردن مستقیم واتساپ/واتساپ بیزینس از جزئیات سفارش
- خروجی و بازیابی کامل JSON با اعتبارسنجی، تراکنش Room و هشدار پیش از جایگزینی
- تنظیمات نام فروشگاه، تأیید حذف و اطلاعات نسخه برنامه
- GitHub Actions برای Debug APK و Release APK/AAB با امضای امن مبتنی بر Secrets
- زبان فارسی + جهت RTL + تقویم شمسی + اعداد فارسی

تب تنظیمات و امکانات تکمیلی در فازهای بعدی ساخته می‌شوند.

## ۷) Build Automation

- Gradle Wrapper استاندارد نسخه ۸.۹ به‌همراه اسکریپت‌های Linux/macOS و Windows در مخزن قرار دارد.
- `.github/workflows/android-build.yml`: اعتبارسنجی Wrapper، JDK 17، کش Gradle، `assembleDebug` و آپلود APK.
- `.github/workflows/android-release.yml`: ساخت `assembleRelease` و `bundleRelease` و آپلود APK/AAB.
- اطلاعات امضا فقط از Secrets با نام‌های `KEYSTORE_FILE`، `KEYSTORE_PASSWORD`، `KEY_ALIAS` و `KEY_PASSWORD` دریافت می‌شوند.
- هیچ کلید امضا یا رمز عبوری در مخزن ذخیره نمی‌شود.
