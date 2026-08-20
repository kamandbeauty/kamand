# اپ | APP2

اپلیکیشن مدیریت کارهای روزانه — Kotlin + Jetpack Compose + Material 3، کاملاً **آفلاین**، با **تقویم شمسی واقعی**، RTL کامل، اعداد فارسی و فونت وزیرمتن.

> Simple + Beautiful + Colorful + Fast

---

## ۱. اجرای پروژه

```bash
cd app2
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

> **توجه:** محیط سندباکسِ توسعه به مخازن Google Maven / Gradle دسترسی نداشت، بنابراین بیلد نهایی باید روی ماشین شما یا GitHub Actions اجرا شود. فایل ورک‌فلوی آماده در `ci/app2-android.yml` قرار دارد — کافی است آن را در `.github/workflows/` قرار دهید (توکن ربات اجازهٔ ساخت فایل workflow را نداشت).
>
> منطق تاریخ و کل سورس کاتلین به‌صورت محلی با کامپایلر Kotlin 2.1.21 بررسی شده و **بدون خطا** است؛ تست‌های تقویم شمسی روی ۹۱٬۳۱۱ روز (۱۹۰۰ تا ۲۱۵۰) اجرا و **همگی پاس** شده‌اند.

### پیش‌نمایش طراحی
`app2/preview/index.html` یک پیش‌نمایش زندهٔ HTML از هویت بصری اپ است (همان توکن‌های رنگ، فونت، تقویم شمسی و اعداد فارسی) که بدون نیاز به اندروید استودیو در مرورگر باز می‌شود.

---

## ۲. تغییر Application ID و نام اپ

هر دو مقدار پارامتریک هستند و بدون دست‌زدن به سورس قابل تغییرند:

```bash
./gradlew :app:assembleRelease \
  -PapplicationId=com.yourcompany.app2 \
  -PappName="اپ"
```

یا به‌صورت دائمی در `app/build.gradle.kts` مقادیر پیش‌فرض `app2ApplicationId` و `app2AppName` را عوض کنید.
نام نمایشی لانچر از `res/values/strings.xml` (فارسی) و `res/values-en/strings.xml` (انگلیسی) خوانده می‌شود.

---

## ۳. امضای APK برای انتشار (کافه‌بازار / مایکت)

```bash
keytool -genkey -v -keystore app2.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias app2
```

سپس فایل `app2/keystore.properties` را بسازید:

```properties
storeFile=app2.jks
storePassword=******
keyAlias=app2
keyPassword=******
```

این فایل در `.gitignore` است و هرگز کامیت نمی‌شود. با وجود آن، `assembleRelease` به‌صورت خودکار خروجی امضاشده می‌دهد.

---

## ۴. قابلیت‌های فاز ۲

**تاریخ و ساعت کاملاً اختیاری** — یک کار می‌تواند بدون تاریخ، فقط با تاریخ، یا با تاریخ و ساعت باشد. کار جدید هیچ تاریخی ندارد مگر کاربر انتخاب کند. کارهای بدون ساعت هرگز ساعت جعلی نمی‌گیرند.

**Daily Planner** — صفحهٔ امروز به بخش‌های «برنامه امروز» (زمان‌دار) ← «هر وقت امروز» ← «بدون تاریخ» ← «انجام‌شده‌ها» تقسیم شده.

**Quick Add + ورود صوتی** — نوار یک‌خطی بالای لیست: بنویس و ذخیره کن. آیکون میکروفون از `RecognizerIntent` استفاده می‌کند و اگر دستگاه موتور تشخیص گفتار نداشته باشد فقط پیام می‌دهد (بدون کرش).

**تکرار** — هر روز / هر هفته / روزهای خاص / هر ماه / هر N روز. با تکمیل یک کار تکرارشونده، نمونهٔ بعدی بلافاصله ساخته می‌شود. «هر ماه» بر مبنای **ماه شمسی** است، نه میلادی.

**Drag & Drop** — نگه‌داشتن و کشیدن در بخش «هر وقت امروز»؛ ترتیب در `sortOrder` ذخیره می‌شود و فقط یک‌بار در پایان کشیدن نوشته می‌شود.

**ویجت‌ها** — ویجت «امروز» (لیست کارها، Progress، تیک زدن مستقیم) و ویجت کوچک «افزودن کار». ویجت مستقیماً از همان دیتابیس Room می‌خواند، پس هرگز از اپ عقب نمی‌ماند.

**پوسته‌های رنگی** — ۶ پوسته (رنگین‌کمانی، سبز، اقیانوس، صورتی، غروب، شب) که Primary، Secondary، Accent، Card، Progress و FAB را با هم تغییر می‌دهند و هرکدام نسخهٔ روشن و تیره دارند.

**گزینه‌های کار** — با نگه‌داشتن روی هر کار یک Bottom Sheet باز می‌شود: انتقال به امروز/فردا/روز دلخواه، حذف تاریخ، تکمیل، یادآوری، ویرایش و حذف — بدون شلوغ کردن لیست اصلی.

---

## ۵. معماری

```
data/       local (Room)، prefs (DataStore)، repo، backup (JSON)
core/       date (تقویم جلالی + فرمترها)، util (اعداد فارسی)
notifications/  AlarmManager + Receiver + WorkManager
ui/         theme، components، today، calendar، profile، addtask، onboarding، search
navigation/ مقصدهای Bottom Navigation
```

- **MVVM** با `ViewModel` + `StateFlow`؛ بدون فریم‌ورک DI (سرویس‌لوکیتور سبک در `App2App`).
- **Offline-First**: بدون مجوز `INTERNET`، بدون لاگین، بدون ارسال داده.
- منبع حقیقت واحد: `TaskRepository` (شامل زمان‌بندی یادآوری تا تسک و آلارم هرگز ناهماهنگ نشوند).

### دیتابیس (Room v1)

`Task`: id, title, description, categoryId, createdAt, dueDate, dueTime, isCompleted, completedAt, priority, reminderEnabled, reminderTime, **repeatRule**, sortOrder
`Category`: id, name, icon, color, builtInKey, createdAt

نسخهٔ دیتابیس **۲** است؛ مهاجرت ۱→۲ ستون `repeatRule` را اضافه می‌کند و هیچ دادهٔ موجودی از دست نمی‌رود.

تاریخ‌ها به‌صورت **epochDay** (تاریخ تقویمی مستقل از منطقهٔ زمانی) و ساعت به‌صورت **دقیقه از نیمه‌شب** ذخیره می‌شوند؛ نمایش شمسی/میلادی صرفاً لایهٔ presentation است.

---

## ۶. تقویم شمسی

پیاده‌سازی واقعی الگوریتم چرخهٔ ۳۳ سالهٔ (Borkowski/خیام) در `core/date/JalaliDate.kt` — نه صرفاً ظاهر فارسیِ تقویم میلادی.

تست‌شده (`app/src/test/.../JalaliDateTest.kt`):
- رفت‌وبرگشت میلادی↔شمسی برای تمام روزهای ۱۹۵۰ تا ۲۱۰۰
- سال‌های کبیسه: ۱۳۹۵، ۱۳۹۹، ۱۴۰۳، ۱۴۰۸، ۱۴۱۲، ۱۴۱۶، ۱۴۲۰
- طول اسفند در سال کبیسه (۳۰) و عادی (۲۹)
- پیوستگی آخر اسفند → ۱ فروردین برای ۱۳۸۰ تا ۱۴۵۰
- شاخص روز هفته با مبنای شنبه = ۰

همین تقویم هم در تب «تقویم» و هم در انتخاب تاریخِ «افزودن کار» استفاده می‌شود.

---

## ۷. یادآوری‌ها

- `AlarmManager.setAndAllowWhileIdle` — بدون مجوز حساس `SCHEDULE_EXACT_ALARM` (فروشگاه‌ها برای اپ To-Do رد می‌کنند) ولی مقاوم در برابر Doze.
- مجوز `POST_NOTIFICATIONS` فقط هنگام ساخت اولین کار درخواست می‌شود، نه در اولین اجرا.
- پس از ریبوت یا آپدیت، `BootReceiver` + `RescheduleWorker` همهٔ یادآوری‌ها را دوباره تنظیم می‌کنند.
- اعلان دکمهٔ «انجام شد» دارد که بدون باز کردن اپ کار را می‌بندد.

---

## ۸. پشتیبان‌گیری

خروجی/ورودی JSON نسخه‌دار از طریق Storage Access Framework (بدون نیاز به مجوز فایل).
فرمت `app2-backup` v1 عمداً transport-agnostic است تا افزودن Cloud Backup در آینده فقط جابه‌جایی همین بایت‌ها باشد.

---

## ۹. کیفیت

```bash
python3 ../tools/verify_resources.py   # بررسی ایستا منابع و ترجمه‌ها
python3 ../tools/check_callsites.py    # بررسی سازگاری امضای توابع و فراخوانی‌ها
```

این اسکریپت بررسی می‌کند: صحت XML، تطابق کامل رشته‌های فا/en و format specifierها، resolve شدن تمام `R.*`ها، **نبود متن فارسی هاردکد در کاتلین**، نبود مجوز INTERNET، سالم بودن فونت‌ها و آیکون‌ها.
