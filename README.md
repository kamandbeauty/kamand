# فاکتوریار (FactorYar)

اپلیکیشن اندرویدی صدور فاکتور، پیش‌فاکتور و فاکتور خرید + مدیریت مشتریان (CRM ساده) + **مدیریت انبار و بارکد** + **ثبت هزینه و سود خالص** + **یادآوری بدهی** + **ویجت صفحه اصلی** + چاپ پوز بلوتوثی + گزارش مالی — طراحی‌شده برای بازار ایران (کافه‌بازار / مایکت). کاملاً آفلاین، بدون وابستگی اجباری به Google Play Services.

## قابلیت‌ها (نسخه رایگان)

- فاکتور فروش / پیش‌فاکتور / فاکتور خرید با اقلام نامحدود، تخفیف و مالیات
- CRM ساده: دفتر حساب مشتری، سابقه خرید، مانده بدهی
- **انبار و بارکد:** تعریف کالا با موجودی اولیه، حد هشدار کمبود، قیمت عمده/خرده، بهای تمام‌شده، دسته‌بندی، اسکن بارکد با دوربین و کسر/افزایش خودکار موجودی هنگام فروش/خرید
- **هزینه‌ها و سود واقعی:** ثبت هزینه با دسته‌بندی دلخواه و محاسبه سود ناخالص و **سود خالص** + نمودار مقایسه‌ای درآمد/هزینه/سود
- **یادآوری بدهی:** شناسایی خودکار معوقات، نوتیفیکیشن محلی، تولید متن آماده و ارسال با Share Intent (پیامک/واتساپ/تلگرام)
- **ویجت صفحه اصلی:** فروش امروز، تعداد معوق و دکمه میان‌بر «فاکتور جدید» — پیرو تم انتخابی کاربر
- چاپ ESC/POS روی پرینتر بلوتوثی ۵۸/۸۰ میلی‌متر، خروجی PDF و اشتراک‌گذاری
- فاکتورهای دوره‌ای، تقویم شمسی، ۵ تم آماده، خروجی CSV/Excel

## فناوری‌ها

- Kotlin + Jetpack Compose (بدون XML Layout)
- MVVM + Clean Architecture چند‌ماژوله — در `docs/ARCHITECTURE.md` کامل توضیح داده شده
- Room + SQLCipher (دیتابیس محلی رمزنگاری‌شده)
- Hilt، WorkManager، DataStore
- تقویم جلالی داخلی (الگوریتم jalaali — بدون وابستگی)
- Poolakey برای اشتراک طلایی (پرداخت درون‌برنامه‌ای بازار)
- CameraX + ML Kit Barcode (نسخه bundled، بدون نیاز به GMS) با fallback خودکار به ZXing و ورود دستی
- Glance AppWidget برای ویجت صفحه اصلی

## ماژول‌ها

| ماژول | نقش |
|---|---|
| `app` | پوسته اپ، ناوبری، WorkManager، Hilt root |
| `core:common` | تقویم جلالی، فرمت‌دهی فارسی/تاریخ، ابزارها (JVM خالص) |
| `core:domain` | مدل‌ها، اینترفیس Repository، UseCaseها (JVM خالص) |
| `core:database` | Entity/DAO/Database Room |
| `core:datastore` | تنظیمات DataStore (تم، شماره‌گذاری، چاپگر…) |
| `core:data` | پیاده‌سازی Repositoryها، SQLCipher key، بایندهای Hilt |
| `core:ui` | موتور تم M3 از Seed، تقویم جلالی UI، کامپوننت‌ها |
| `core:pdf` | تولید PDF فاکتور/گزارش با PdfDocument |
| `core:printer` | چاپ ESC/POS بلوتوثی + رندر رسید |
| `core:billing` | Poolakey — اشتراک طلایی |
| `core:barcode` | اسکن بارکد (CameraX + ML Kit با fallback به ZXing و ورود دستی) |
| `feature:*` | dashboard / invoices / customers / reports / products / expenses / settings |

## پیش‌نیازها و Build

1. **JDK 17** و Android SDK 34 (از Android Studio نسخه Koala به بالا: AGP 8.5 / Gradle 8.10)
2. اجرا:
   ```bash
   ./gradlew :app:assembleDebug        # APK دیباگ
   ./gradlew :app:assembleRelease      # ریلیز (R8 فعال)
   ./gradlew testDebugUnitTest         # تست‌های واحد (فاکتور، جلالی، سود، انبار، یادآوری)
   ```
3. اگر Maven گوگل در دسترس نیست، میرورهای Myket/Bazaar در `settings.gradle.kts` به‌صورت خودکار fallback هستند.

## راه‌اندازی برای انتشار

1. **فونت وزیرمتن** (OFL): فایل‌های `vazirmatn_regular/medium/bold.ttf` را در `core/ui/src/main/res/font/` قرار داده و در `FactorYarTheme.kt` مقدار `FyFontFamily` را با `FontFamily(Font(R.font.vazirmatn_regular))…` پر کنید.
2. **Poolakey:** کلید عمومی RSA را از پنل توسعه‌دهندگان بازار در `BillingManager.RSA_PUBLIC_KEY` جای‌گذاری و SKUها را بسازید (`factoryar_gold_monthly/yearly`).
3. **امضای انتشار:** keystore خود را بسازید و در `app/build.gradle.kts` بلوک `signingConfigs` را اضافه کنید.
4. تست روی دستگاهی بدون Google Play Services (مهم‌ترین سناریوی بازار ایران) — به‌ویژه مسیر اسکن بارکد که باید به ZXing یا ورود دستی برگردد.
5. تست ویجت: افزودن به صفحه اصلی، تغییر تم در تنظیمات و بررسی به‌روزرسانی رنگ ویجت.
- حجم APK هدف‌گذاری: < ۱۵ مگابایت. مدل bundled بارکد حدود ۲–۳ مگابایت اضافه می‌کند؛ در صورت نیاز به کاهش حجم می‌توان به نسخه `barcode-scanning-common` + وابستگی GMS سوییچ کرد (اما سازگاری بدون GMS از دست می‌رود).

## مهاجرت دیتابیس

نسخه دیتابیس **۲** است. `MIGRATION_1_2` در `core/database/.../migration/Migrations.kt` جدول‌های `products`، `product_categories`، `stock_movements`، `expenses`، `expense_categories` را می‌سازد و ستون‌های `productId` و `costPrice` را به `invoice_items` اضافه می‌کند. `fallbackToDestructiveMigration` **حذف شده** تا داده کاربران در به‌روزرسانی از بین نرود؛ برای هر تغییر بعدی اسکیما حتماً یک Migration جدید بنویسید.

## نکته درباره Gradle Wrapper

فایل `gradle/wrapper/gradle-wrapper.jar` در این محیط تولید نشده (بدون JDK/شبکه). روی سیستم خود با یک‌بار اجرای `gradle wrapper --gradle-version 8.10.2` یا با نصب Gradle هر نسخه ≥8.7 و اجرای `gradle wrapper` تولید می‌شود.

## نقشه راه فاز ۲

- درگاه پرداخت آنلاین ایرانی (زرین‌پال/…) برای لینک پرداخت فاکتور
- بک‌اند اختصاصی برای همگام‌سازی چند دستگاه (نقطه اتصال: اینترفیس‌های Repository در `core:domain`)
- اتصال به MPOS با پرداخت کارتی
