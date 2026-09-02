# ساختن اپ جدید از روی «روزی»

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
  --dir memory \
  --package com.studiojavid.memory \
  --prefix Memory \
  --name-fa "دفتر خاطرات و تولد" \
  --name-fa-short "خاطرات" \
  --name-en "Memory"
```

`--name-fa` نام کامل لانچر است و `--name-fa-short` واژه‌ای که داخل جمله‌های
فارسی جای «روزی» می‌نشیند (مثلاً در متن نوتیفیکیشن).

اسکریپت در یک پاس همهٔ چیزهایی را که هویت روزی را حمل می‌کنند بازنویسی می‌کند:

| مورد | از | به |
|---|---|---|
| Application ID و namespace | `com.roozi.app` | `com.studiojavid.memory` |
| مسیر پکیج کاتلین | `java/com/roozi/app/…` | `java/com/studiojavid/memory/…` |
| پیشوند تایپ‌ها | `RooziTheme`, `RooziDatabase`, `RooziHeader`, … | `Memory` |
| نام تم‌ها | `Theme.Roozi.Splash` | `Theme.Memory.Splash` |
| فایل دیتابیس | `roozi.db` | `memory.db` |
| اکشن‌های Broadcast | `com.roozi.app.action.REMIND` | `com.studiojavid.memory.action.REMIND` |
| فرمت فایل پشتیبان | `roozi-backup` | `memory-backup` |
| `rootProject.name` | `ROOZI` | `MEMORY` |
| ورک‌فلو | `roozi/ci/roozi-android.yml` | `memory/ci/memory-android.yml` (نام جاب، `working-directory`، نام artifactها) |
| `app_name` / `app_name_short` | روزی | دفتر خاطرات و تولد / Memory |
| `versionCode` / `versionName` | ۲ / 1.0.1 | ۱ / 1.0.0 |

کپی نمی‌شوند: `build/`, `.gradle/`, `keystore.properties`, `release.keystore`,
`local.properties`.

### کلید امضا

به‌صورت پیش‌فرض ورک‌فلوی اپ دوم از **همان چهار سکرت روزی** استفاده می‌کند
(`ROZI_RELEASE_*`) — یعنی هر دو اپ با یک کلید ناشر امضا می‌شوند، که برای
انتشار زیر یک حساب کافه‌بازار درست است. اگر اپ دوم کلید جداگانه می‌خواهد:

```bash
python3 tools/fork_app.py … --secret-prefix MEMORY
```

آن‌وقت باید چهار سکرت `MEMORY_RELEASE_KEYSTORE_BASE64` و بقیه را در تنظیمات مخزن
بسازید.

## بعد از فورک

```bash
python3 tools/verify_resources.py --module memory
python3 tools/check_callsites.py  --module memory
```

هر دو اسکریپت حالا پارامتر `--module` می‌گیرند و پیش‌فرضشان `roozi` است، پس
بررسی‌های قبلی روزی دست‌نخورده کار می‌کنند.

سپس فایل `memory/ci/memory-android.yml` را از طریق ویرایشگر وب گیت‌هاب در
`.github/workflows/memory-android.yml` کپی کنید — توکن ربات اجازهٔ ساخت یا
ویرایش فایل‌های `.github/workflows/` را ندارد.

## تغییر نام بعدی

نیازی به تغییر تدریجی نیست؛ پوشه را پاک کنید و دوباره با مقادیر جدید بسازید:

```bash
python3 tools/fork_app.py --dir habit --package com.javidstudio.habit \
  --prefix Habit --name-fa "عادت" --name-en "Habit" --force
```

فورک فقط **نقطهٔ شروع** است. اپ `memory/` بعد از فورک به‌صورت دستی به یک محصول
دیگر تبدیل شد: لیست کار، ویجت‌ها و یادآوری تسک حذف شدند و خاطرهٔ روزانه،
حال‌وهوا و عکس اضافه شد. یعنی وقتی کدِ اختصاصیِ اپ نوشته شد، دیگر
`--force` گزینه نیست — از آن به بعد اپ زندگی مستقل خودش را دارد.

## چیزی که باید عوض شود و اسکریپت نمی‌تواند حدس بزند

اینها هویتِ بصری و محتوایی‌اند و بعد از فورک باید دستی جایگزین شوند:

- `app/src/main/res/mipmap-*/ic_launcher*.png` — آیکون لانچر (کوآلای روزی)
- `app/src/main/res/drawable-*/ic_splash_koala.png` و `ic_brand_mark.png`
- `branding/` — فایل‌های منبع آیکون
- `store/` (در ریشهٔ مخزن) — متن‌های فروشگاه مخصوص روزی است
- محتوای صفحه‌ها و رشته‌های `strings.xml` که مخصوص لیست‌کار است

## نمونه‌ای که واقعاً ساخته شد

«دفتر خاطرات و تولد» (`com.studiojavid.memory`) با همین اسکریپت ساخته و بعد
دستی به محصول دیگری تبدیل شد:

| حذف شد | جایگزین |
|---|---|
| Task / Category (Entity، DAO، Repository، ViewModel) | `MemoryEntity` + `MemoryRepository` + `MemoryViewModel` |
| تب «امروز»، افزودن کار، Quick Add، تکرار، Drag & Drop | تب «خاطرات»: یک صفحه برای هر روز، حال‌وهوا، عکس |
| ویجت‌های صفحهٔ اصلی و یادآوری تسک | فقط یادآوری تولد |
| «تولدها» به‌عنوان یک قفسه در تب یادداشت | تب مستقل «تولدها» |
| streak کارهای انجام‌شده | streak نوشتن |
| دسته‌بندی‌ها در پروفایل | تفکیک حال‌وهوا |

اسکیمای دیتابیس هم از **نسخهٔ ۱** شروع شد و مهاجرت‌های روزی دور ریخته شدند —
چون آن اپ هرگز منتشر نشده بود، هیچ دیتابیس نصب‌شده‌ای برای مهاجرت وجود نداشت
و نگه‌داشتن جدول‌های مردهٔ Task فقط مهاجرت‌های آینده را گمراه می‌کرد.

آن اپ حالا روی **برنچ `memory`** زندگی می‌کند و از این برنچ حذف شده، تا اینجا
فقط روزی بماند.

## جدا کردن یک اپ روی برنچ خودش

وقتی اپ فورک‌شده به بلوغ رسید، آن را روی برنچ خودش ببرید تا دو محصول در یک
برنچ قاطی نشوند. ساده‌ترین راه همان کاری است که برای `memory` انجام شد: کل
برنچ را در گیت‌هاب کپی کنید (Branches ← New branch)، بعد از برنچ اصلی پوشهٔ
اپ جدید را پاک کنید و از برنچ جدید پوشهٔ روزی را.
