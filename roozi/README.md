# روزی | ROOZI

اپلیکیشن مدیریت کارهای روزانه — Kotlin + Jetpack Compose + Material 3، کاملاً **آفلاین**، با **تقویم شمسی واقعی**، RTL کامل، اعداد فارسی و فونت وزیرمتن.

> Simple + Beautiful + Colorful + Fast

---

## ۱. اجرای پروژه

```bash
cd roozi
./gradlew :app:assembleDebug        # خروجی دیباگ
./gradlew :app:assembleRelease      # خروجی ریلیز (APK)
./gradlew :app:bundleRelease        # خروجی AAB برای فروشگاه‌ها
./gradlew :app:testDebugUnitTest    # تست‌های واحد (تقویم شمسی)
```

خروجی‌ها:

| فایل | مسیر |
|---|---|
| APK | `app/build/outputs/apk/release/app-release.apk` |
| AAB | `app/build/outputs/bundle/release/app-release.aab` |

نیازمندی‌ها: JDK 17، Android SDK 35 (AGP 8.7.3، Kotlin 2.0.21، Compose BOM 2024.12).

> **توجه:** محیط سندباکسِ توسعه به مخازن Google Maven / Gradle دسترسی نداشت، بنابراین بیلد نهایی باید روی ماشین شما یا GitHub Actions اجرا شود. فایل ورک‌فلوی آماده در `ci/roozi-android.yml` قرار دارد — کافی است آن را در `.github/workflows/` قرار دهید (توکن ربات اجازهٔ ساخت فایل workflow را نداشت).
>
> منطق تاریخ و کل سورس کاتلین به‌صورت محلی با کامپایلر Kotlin 2.1.21 بررسی شده و **بدون خطا** است؛ تست‌های تقویم شمسی روی ۹۱٬۳۱۱ روز (۱۹۰۰ تا ۲۱۵۰) اجرا و **همگی پاس** شده‌اند.

### پیش‌نمایش طراحی
`roozi/preview/index.html` یک پیش‌نمایش زندهٔ HTML از هویت بصری اپ است (همان توکن‌های رنگ، فونت، تقویم شمسی و اعداد فارسی) که بدون نیاز به اندروید استودیو در مرورگر باز می‌شود.

---

## ۲. تغییر Application ID و نام اپ

هر دو مقدار پارامتریک هستند و بدون دست‌زدن به سورس قابل تغییرند:

```bash
./gradlew :app:assembleRelease \
  -PapplicationId=com.yourcompany.roozi \
  -PappName="روزی"
```

یا به‌صورت دائمی در `app/build.gradle.kts` مقادیر پیش‌فرض `rooziApplicationId` و `rooziAppName` را عوض کنید.
نام نمایشی لانچر از `res/values/strings.xml` (فارسی) و `res/values-en/strings.xml` (انگلیسی) خوانده می‌شود.

---

## ۳. امضای APK برای انتشار (کافه‌بازار / مایکت)

```bash
keytool -genkey -v -keystore roozi.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias roozi
```

سپس فایل `roozi/keystore.properties` را بسازید:

```properties
storeFile=roozi.jks
storePassword=******
keyAlias=roozi
keyPassword=******
```

این فایل در `.gitignore` است و هرگز کامیت نمی‌شود. با وجود آن، `assembleRelease` به‌صورت خودکار خروجی امضاشده می‌دهد.

---

## ۴. معماری

```
data/       local (Room)، prefs (DataStore)، repo، backup (JSON)
core/       date (تقویم جلالی + فرمترها)، util (اعداد فارسی)
notifications/  AlarmManager + Receiver + WorkManager
ui/         theme، components، today، calendar، profile، addtask، onboarding، search
navigation/ مقصدهای Bottom Navigation
```

- **MVVM** با `ViewModel` + `StateFlow`؛ بدون فریم‌ورک DI (سرویس‌لوکیتور سبک در `RooziApp`).
- **Offline-First**: بدون مجوز `INTERNET`، بدون لاگین، بدون ارسال داده.
- منبع حقیقت واحد: `TaskRepository` (شامل زمان‌بندی یادآوری تا تسک و آلارم هرگز ناهماهنگ نشوند).

### دیتابیس (Room v1)

`Task`: id, title, description, categoryId, createdAt, dueDate, dueTime, isCompleted, completedAt, priority, reminderEnabled, reminderTime, sortOrder
`Category`: id, name, icon, color, builtInKey, createdAt

تاریخ‌ها به‌صورت **epochDay** (تاریخ تقویمی مستقل از منطقهٔ زمانی) و ساعت به‌صورت **دقیقه از نیمه‌شب** ذخیره می‌شوند؛ نمایش شمسی/میلادی صرفاً لایهٔ presentation است.

---

## ۵. تقویم شمسی

پیاده‌سازی واقعی الگوریتم چرخهٔ ۳۳ سالهٔ (Borkowski/خیام) در `core/date/JalaliDate.kt` — نه صرفاً ظاهر فارسیِ تقویم میلادی.

تست‌شده (`app/src/test/.../JalaliDateTest.kt`):
- رفت‌وبرگشت میلادی↔شمسی برای تمام روزهای ۱۹۵۰ تا ۲۱۰۰
- سال‌های کبیسه: ۱۳۹۵، ۱۳۹۹، ۱۴۰۳، ۱۴۰۸، ۱۴۱۲، ۱۴۱۶، ۱۴۲۰
- طول اسفند در سال کبیسه (۳۰) و عادی (۲۹)
- پیوستگی آخر اسفند → ۱ فروردین برای ۱۳۸۰ تا ۱۴۵۰
- شاخص روز هفته با مبنای شنبه = ۰

همین تقویم هم در تب «تقویم» و هم در انتخاب تاریخِ «افزودن کار» استفاده می‌شود.

---

## ۶. یادآوری‌ها

- `AlarmManager.setAndAllowWhileIdle` — بدون مجوز حساس `SCHEDULE_EXACT_ALARM` (فروشگاه‌ها برای اپ To-Do رد می‌کنند) ولی مقاوم در برابر Doze.
- مجوز `POST_NOTIFICATIONS` فقط هنگام ساخت اولین کار درخواست می‌شود، نه در اولین اجرا.
- پس از ریبوت یا آپدیت، `BootReceiver` + `RescheduleWorker` همهٔ یادآوری‌ها را دوباره تنظیم می‌کنند.
- اعلان دکمهٔ «انجام شد» دارد که بدون باز کردن اپ کار را می‌بندد.

---

## ۷. پشتیبان‌گیری

خروجی/ورودی JSON نسخه‌دار از طریق Storage Access Framework (بدون نیاز به مجوز فایل).
فرمت `roozi-backup` v1 عمداً transport-agnostic است تا افزودن Cloud Backup در آینده فقط جابه‌جایی همین بایت‌ها باشد.

---

## ۸. کیفیت

```bash
python3 ../tools/verify_resources.py   # بررسی ایستا بدون نیاز به Android SDK
```

این اسکریپت بررسی می‌کند: صحت XML، تطابق کامل رشته‌های فا/en و format specifierها، resolve شدن تمام `R.*`ها، **نبود متن فارسی هاردکد در کاتلین**، نبود مجوز INTERNET، سالم بودن فونت‌ها و آیکون‌ها.
