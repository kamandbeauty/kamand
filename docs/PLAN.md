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
│   └── common/                  # PlaceholderScreen
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
| ۱ | اسکلت پروژه + دیتابیس + صفحه داشبورد + بیلد | ✅ این فاز |
| ۲ | مدیریت مشتری‌ها (افزودن/ویرایش/حذف/جستجو/تاریخچه) | بعدی |
| ۳ | مدیریت محصولات (افزودن/ویرایش/حذف/موجودی) | بعدی |
| ۴ | مدیریت سفارش‌ها (ثبت/وضعیت/جزئیات) | بعدی |
| ۵ | گزارش‌های ساده (امروز/این ماه/سود) | بعدی |
| ۶ | پیام آماده واتساپ | بعدی |
| ۷ | سیستم Backup (Export/Import JSON) | بعدی |
| ۸ | تنظیمات (نام فروشگاه/تایید حذف/درباره) | بعدی |
| ۹ | تست، آماده‌سازی و انتشار (کافه‌بازار و مایکت) | بعدی |

> **خارج از محدوده MVP:** سیستم چندکاربره، پنل مدیریت، سرور، API، اتصال اینستاگرام، پرداخت آنلاین، چت داخلی، حسابداری و انبارداری پیچیده.

## 6) وضعیت فعلی پیاده‌سازی

- اسکلت کامل پروژه (Gradle, Manifest, Theme, Navigation, Hilt, DI)
- مدل داده کامل (۴ جدول + روابط + DAOها + Repositoryها)
- صفحه داشبورد: فروش امروز، سود امروز، سفارش‌های باز، تعداد مشتری‌ها، آخرین سفارش‌ها
- زبان فارسی + جهت RTL + تقویم شمسی + اعداد فارسی

سایر تب‌ها فعلاً به‌صورت Placeholder هستند و در فازهای بعدی ساخته می‌شوند.
