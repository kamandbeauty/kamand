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

## وضعیت فعلی (فاز ۳)

- [x] اسکلت کامل پروژه (Gradle, Manifest, Theme, Navigation, Hilt, DI)
- [x] مدل داده کامل: `customers` ،`products` ،`orders` ،`order_items`
- [x] صفحه داشبورد: فروش امروز، سود امروز، سفارش‌های باز، تعداد مشتری‌ها، آخرین سفارش‌ها
- [x] مدیریت مشتری‌ها: افزودن، ویرایش، حذف، جست‌وجو، جزئیات و تاریخچه سفارش‌ها
- [x] مدیریت محصولات: افزودن، ویرایش، حذف، جست‌وجو، قیمت‌ها و موجودی
- [x] زبان فارسی + جهت RTL + تقویم شمسی + اعداد فارسی

تب‌های سفارش‌ها و تنظیمات طبق نقشه راه (فایل `docs/PLAN.md`) در فازهای بعدی ساخته می‌شوند.

## نحوه Build

پیش‌نیاز: **Android Studio** (نسخه‌های اخیر) + **JDK 17** + **Android SDK (Platform 34)**.

1. پروژه را در Android Studio باز کنید (`File → Open`).
2. بگذارید Gradle Sync کامل شود (وابستگی‌ها از `google()` و `mavenCentral()` دریافت می‌شوند).
3. `Build → Build App Bundle(s)/APK(s) → Build APK(s)` یا از ترمینال:
   ```bash
   ./gradlew assembleDebug
   ```
4. خروجی: `app/build/outputs/apk/debug/app-debug.apk`

### نکته برای کاربران ایران (آینه/میرور)

اگر دریافت وابستگی‌ها از مخزن‌های پیش‌فرض برای شما کند یا مسدود است، می‌توانید از طریق
یک فایل `init.gradle` آینه‌ی ایرانی را اضافه کنید. یک نمونه آماده به‌نام `init.gradle.example`
در ریشه پروژه قرار داده شده است. (پروژه فقط از `google()` و `mavenCentral()` استفاده می‌کند.)

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
├── ui/{theme,navigation,home,customers,products,common}
└── util/                       # DateUtils + FormatUtils
```

جزئیات کامل معماری، دیاگرام دیتابیس، لیست وابستگی‌ها و نقشه راه در [docs/PLAN.md](docs/PLAN.md).

## وابستگی‌ها

AGP 8.5.2 · Kotlin 2.0.21 · Compose BOM 2024.09.02 · Navigation 2.7.7 · Hilt 2.52 · Room 2.6.1 · Coroutines 1.8.1
