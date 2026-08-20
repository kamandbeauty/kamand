# ساختن اپ دوم از روی «روزی»

بخش بزرگی از روزی زیرساخت عمومی است و به لیست‌کار بودنِ اپ ربطی ندارد:

- موتور تقویم جلالی (`core/date/JalaliDate.kt` — چرخهٔ ۳۳ سالهٔ Borkowski) و
  `DateFormatter` / `MonthPage`
- اعداد فارسی، RTL کامل، فونت وزیرمتن، ۶ پوستهٔ رنگی و کل دیزاین‌سیستم
  (`ui/theme/`, `ui/components/`)
- لایهٔ Room + Repository + `UserPreferences` (DataStore)
- یادآوری‌های دقیق (`AlarmManager` + WorkManager backstop + BootReceiver)
- پشتیبان‌گیری/بازیابی JSON، آنبوردینگ، ویجت‌های صفحهٔ اصلی، CrashReporter
- ورک‌فلوی CI با امضای ریلیز و بررسی امضای APK
- بررسی‌های ایستا: `tools/verify_resources.py` و `tools/check_callsites.py`

برای اپ بعدی این‌ها دوباره نوشته نمی‌شوند.

## چرا کپی، نه ماژول مشترک؟

اگر یک ماژول `:core` مشترک بین دو اپ می‌ساختیم، هر تغییری در روزی می‌توانست اپ
دوم را بشکند و برعکس — و چون هر دو مستقل روی کافه‌بازار منتشر می‌شوند، این
وابستگی هزینه‌اش از فایدهٔ اشتراک بیشتر است. به‌جایش اپ دوم یک **کپی کاملِ
مستقل** است که می‌تواند آزادانه واگرا شود: صفحه‌های متفاوت، اسکیمای دیتابیس
متفاوت، چرخهٔ انتشار متفاوت.

**روزی هرگز تغییر نمی‌کند** — اسکریپت فورک فقط از آن می‌خواند.

## اجرا

```bash
python3 tools/fork_app.py \
  --dir app2 \
  --package com.javidstudio.app2 \
  --prefix App2 \
  --name-fa "اپ دوم" \
  --name-en "App2"
```

اسکریپت در یک پاس همهٔ چیزهایی را که هویت روزی را حمل می‌کنند بازنویسی می‌کند:

| مورد | از | به |
|---|---|---|
| Application ID و namespace | `com.roozi.app` | `--package` |
| مسیر پکیج کاتلین | `java/com/roozi/app/…` | `java/com/javidstudio/app2/…` |
| پیشوند تایپ‌ها | `RooziTheme`, `RooziDatabase`, `RooziHeader`, … | `--prefix` |
| نام تم‌ها | `Theme.Roozi.Splash` | `Theme.App2.Splash` |
| فایل دیتابیس | `roozi.db` | `app2.db` |
| اکشن‌های Broadcast | `com.roozi.app.action.REMIND` | `com.javidstudio.app2.action.REMIND` |
| فرمت فایل پشتیبان | `roozi-backup` | `app2-backup` |
| `rootProject.name` | `ROOZI` | `APP2` |
| ورک‌فلو | `roozi/ci/roozi-android.yml` | `app2/ci/app2-android.yml` (نام جاب، `working-directory`، نام artifactها) |
| `app_name` / `app_name_short` | روزی | `--name-fa` / `--name-en` |
| `versionCode` / `versionName` | ۲ / 1.0.1 | ۱ / 1.0.0 |

کپی نمی‌شوند: `build/`, `.gradle/`, `keystore.properties`, `release.keystore`,
`local.properties`.

### کلید امضا

به‌صورت پیش‌فرض ورک‌فلوی اپ دوم از **همان چهار سکرت روزی** استفاده می‌کند
(`ROZI_RELEASE_*`) — یعنی هر دو اپ با یک کلید ناشر امضا می‌شوند، که برای
انتشار زیر یک حساب کافه‌بازار درست است. اگر اپ دوم کلید جداگانه می‌خواهد:

```bash
python3 tools/fork_app.py … --secret-prefix APP2
```

آن‌وقت باید چهار سکرت `APP2_RELEASE_KEYSTORE_BASE64` و بقیه را در تنظیمات مخزن
بسازید.

## بعد از فورک

```bash
python3 tools/verify_resources.py --module app2
python3 tools/check_callsites.py  --module app2
```

هر دو اسکریپت حالا پارامتر `--module` می‌گیرند و پیش‌فرضشان `roozi` است، پس
بررسی‌های قبلی روزی دست‌نخورده کار می‌کنند.

سپس فایل `app2/ci/app2-android.yml` را از طریق ویرایشگر وب گیت‌هاب در
`.github/workflows/app2-android.yml` کپی کنید — توکن ربات اجازهٔ ساخت یا
ویرایش فایل‌های `.github/workflows/` را ندارد.

## تغییر نام بعدی

نیازی به تغییر تدریجی نیست؛ پوشه را پاک کنید و دوباره با مقادیر جدید بسازید:

```bash
python3 tools/fork_app.py --dir habit --package com.javidstudio.habit \
  --prefix Habit --name-fa "عادت" --name-en "Habit" --force
```

به همین دلیل بهتر است تا وقتی هویت اپ دوم قطعی نشده، کدِ اختصاصیِ آن نوشته
نشود — بعد از آن، فورک نقطهٔ شروع است و از آن به بعد دستی توسعه داده می‌شود.

## چیزی که باید عوض شود و اسکریپت نمی‌تواند حدس بزند

اینها هویتِ بصری و محتوایی‌اند و بعد از فورک باید دستی جایگزین شوند:

- `app/src/main/res/mipmap-*/ic_launcher*.png` — آیکون لانچر (کوآلای روزی)
- `app/src/main/res/drawable-*/ic_splash_koala.png` و `ic_brand_mark.png`
- `branding/` — فایل‌های منبع آیکون
- `store/` (در ریشهٔ مخزن) — متن‌های فروشگاه مخصوص روزی است
- محتوای صفحه‌ها و رشته‌های `strings.xml` که مخصوص لیست‌کار است

> در متن‌های فروشگاهی هیچ ادعایی دربارهٔ تبلیغات یا «کاملاً آفلاین» ننویسید —
> قاعدهٔ ثبت‌شده در `store/README.md` برای اپ دوم هم برقرار است.
