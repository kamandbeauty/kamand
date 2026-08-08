# نصب Android SDK بدون دسترسی به dl.google.com

اگر Android Studio می‌گوید **«Android SDK را انتخاب کنید»** یا خطای
`Failed to download any source lists` می‌دهد، یعنی SDK نصب نیست و ویزارد هم
نمی‌تواند نصبش کند چون `dl.google.com` در ایران مسدود است.

راه‌حل: پکیج‌ها را دستی از میرور مایکت دانلود و در مسیر درست قرار می‌دهیم.

> ⚠️ **نکتهٔ مهم:** آدرس `maven.myket.ir` را در بخش
> `SDK Update Sites` اندروید استودیو **اضافه نکنید**. آن میرورِ کتابخانه‌های
> Maven است، نه SDK، و باعث خطای `UnknownHost sys-img.xml` می‌شود.

---

## گام ۱ — مسیر SDK را بسازید

| سیستم‌عامل | مسیر پیشنهادی |
|---|---|
| ویندوز | `C:\Users\<user>\AppData\Local\Android\Sdk` |
| لینوکس | `~/Android/Sdk` |
| مک | `~/Library/Android/sdk` |

```bash
mkdir -p ~/Android/Sdk
```

---

## ⚡ راه سریع (ویندوز) — توصیه‌شده

یک دستور، همه‌چیز را نصب و تنظیم می‌کند (لینک‌های ثابت و تأییدشده، بدون پارس CSV):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup-sdk-windows.ps1
```

این اسکریپت:
- Platform 34، Build-Tools 34، Platform-Tools و cmdline-tools را نصب می‌کند
- **پوشهٔ تودرتو را خودش رفع می‌کند** (علت اصلی خطای `hash string`)
- `source.properties`، فایل‌های لایسنس و `local.properties` را می‌سازد
- در پایان صحت هر مورد را بررسی می‌کند

گزینه‌ها: `-Force` (نصب مجدد) · `-Emulator` (امولاتور ۴۲۹MB)

پس از آن حتماً:

```powershell
.\gradlew.bat --stop
.\gradlew.bat :app:assembleDebug
```

---

## گام ۲ — دانلود پکیج‌ها

### روش الف) خودکار

**ویندوز (PowerShell):**

```powershell
powershell -ExecutionPolicy Bypass -File scripts\fetch-android-sdk.ps1 -List
powershell -ExecutionPolicy Bypass -File scripts\fetch-android-sdk.ps1
powershell -ExecutionPolicy Bypass -File scripts\fetch-android-sdk.ps1 -Emulator
```

**لینوکس / مک:**

```bash
bash scripts/fetch-android-sdk.sh --list
bash scripts/fetch-android-sdk.sh
```

### روش ب) دستی — لینک مستقیم

این پروژه `compileSdk = 34` و `minSdk = 24` دارد. **سه مورد اول اجباری‌اند.**

#### ۱. Android Platform 34 — الزامی (۶۳ مگابایت)

مقصد: `<SDK>/platforms/android-34/`

```
https://maven.myket.ir/android-sdk/platform-34-ext7_r03.zip
```

> پس از extract، اگر پوشهٔ داخلی `android-14` یا مشابه بود، نامش را به
> `android-34` تغییر دهید.

#### ۲. Build-Tools 34.0.0 — الزامی (~۵۰ مگابایت)

مقصد: `<SDK>/build-tools/34.0.0/`

فایل CSV را باز کنید و ردیف `build-tools;34.0.0` مربوط به سیستم‌عامل خود را
بردارید: <https://maven.myket.ir/sdk-archives.csv>

#### ۳. Platform-Tools — الزامی (adb و fastboot)

مقصد: `<SDK>/platform-tools/`

| سیستم | لینک |
|---|---|
| لینوکس | `https://maven.myket.ir/android-sdk/platform-tools_r37.0.0-linux.zip` |
| ویندوز | `https://maven.myket.ir/android-sdk/platform-tools_r37.0.0-win.zip` |
| مک | `https://maven.myket.ir/android-sdk/platform-tools_r37.0.0-darwin.zip` |

#### ۴. Emulator — اختیاری (~۴۰۰ مگابایت)

مقصد: `<SDK>/emulator/`

| سیستم | لینک |
|---|---|
| لینوکس | `https://maven.myket.ir/android-sdk/emulator-linux_x64-15142779.zip` |
| ویندوز | `https://maven.myket.ir/android-sdk/emulator-windows_x64-15142779.zip` |
| مک | `https://maven.myket.ir/android-sdk/emulator-darwin_x64-15142779.zip` |

#### ۵. System Image — اختیاری (فقط اگر امولاتور می‌خواهید)

مقصد: `<SDK>/system-images/android-34/google_apis/x86_64/`

در فایل CSV دنبال `system-images;android-34;...` بگردید.

> 💡 **پیشنهاد:** به‌جای امولاتور از **گوشی واقعی** استفاده کنید — سبک‌تر،
> سریع‌تر و برای این پروژه واقعی‌تر است (تست چاپگر بلوتوثی و اسکن بارکد روی
> امولاتور عملاً ممکن نیست). کافی است روی گوشی
> `Developer options → USB debugging` را فعال کنید.

---

## گام ۳ — ساختار نهایی

```
Android/Sdk/
├── platforms/
│   └── android-34/          ← باید android.jar داشته باشد
├── build-tools/
│   └── 34.0.0/              ← باید aapt2 و d8 داشته باشد
├── platform-tools/          ← باید adb داشته باشد
└── emulator/                (اختیاری)
```

بررسی صحت نصب:

```bash
ls ~/Android/Sdk/platforms/android-34/android.jar
ls ~/Android/Sdk/build-tools/34.0.0/aapt2
~/Android/Sdk/platform-tools/adb version
```

---

## گام ۴ — معرفی مسیر به پروژه

فایل `local.properties` را در ریشهٔ پروژه بسازید:

```properties
# لینوکس / مک
sdk.dir=/home/<user>/Android/Sdk

# ویندوز (بک‌اسلش‌ها را escape کنید)
# sdk.dir=C\:\\Users\\<user>\\AppData\\Local\\Android\\Sdk
```

در Android Studio هم: `File → Project Structure → SDK Location` و همین مسیر
را وارد کنید.

---

## گام ۵ — پذیرش لایسنس‌ها

بدون این مرحله بیلد با خطای «licenses not accepted» متوقف می‌شود.

اگر `cmdline-tools` نصب کرده‌اید:

```bash
~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --licenses
```

**اگر cmdline-tools ندارید** (چون آن هم از گوگل می‌آید)، لایسنس‌ها را دستی
بسازید — این هش‌ها ثابت و عمومی هستند:

```bash
mkdir -p ~/Android/Sdk/licenses
cd ~/Android/Sdk/licenses

printf '\n8933bad161af4178b1185d1a37fbf41ea5269c55\nd56f5187479451eabf01fb78af6dfcb131a6481e\n24333f8a63b6825ea9c5514f83c2829b004d1fee\n' > android-sdk-license
printf '\n84831b9409646a918e30573bab4c9c91346d8abd\n504667f4c0de7af1a06de9f4b1727b84351f2910\n' > android-sdk-preview-license
printf '\n33b6a2b64607f11b759f320ef9dff4ae5c47d97a\n' > android-googletv-license
printf '\nd975f751698a77b662f1254ddbeed3901e976f5a\n' > intel-android-extra-license
printf '\n33b6a2b64607f11b759f320ef9dff4ae5c47d97a\n' > android-sdk-arm-dbt-license
```

در ویندوز همین فایل‌ها را در `%LOCALAPPDATA%\Android\Sdk\licenses\` بسازید
(بدون پسوند، با محتوای هش).

---

## گام ۶ — بیلد

```bash
./gradlew :app:assembleDebug
```

APK خروجی: `app/build/outputs/apk/debug/app-debug.apk`

نصب روی گوشی متصل:

```bash
./gradlew :app:installDebug
```

---

## خطای «Failed to find target with hash string 'android-34'»

یعنی AGP مسیر SDK را **پیدا کرده** ولی داخلش پلتفرم ۳۴ سالم نیست.
شایع‌ترین علت: **پوشهٔ تودرتو** بعد از extract.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-sdk.ps1        # بررسی
powershell -ExecutionPolicy Bypass -File scripts\check-sdk.ps1 -Fix   # بررسی + اصلاح
```

### بررسی دستی

ساختار باید **دقیقاً** این باشد:

```
Sdk\platforms\android-34\android.jar          ✅
Sdk\platforms\android-34\source.properties    ✅
```

نه این:

```
Sdk\platforms\android-34\android-14\android.jar   ❌ لایه اضافه
Sdk\platforms\platform-34-ext7\android.jar         ❌ نام غلط
```

### فایل source.properties

بدون آن، AGP پلتفرم را نمی‌شناسد حتی اگر `android.jar` سر جایش باشد:

```properties
AndroidVersion.ApiLevel=34
Pkg.Revision=3
```

### بعد از هر اصلاح

```powershell
.\gradlew.bat --stop
.\gradlew.bat :app:assembleDebug
```

---

## عیب‌یابی

| خطا | علت و راه‌حل |
|---|---|
| `SDK location not found` | `local.properties` نیست یا مسیر غلط است |
| `Failed to find Platform SDK with path: platforms;android-34` | پوشهٔ `platforms/android-34` خالی یا نام پوشه اشتباه است |
| `Installed Build Tools revision X is corrupted` | فایل ناقص دانلود شده — پوشه را پاک و دوباره extract کنید |
| `licenses have not been accepted` | گام ۵ را انجام دهید |
| `Failed to download any source lists` | بی‌خطر است؛ با `android.builder.sdkDownload=false` در `gradle.properties` خاموش شده |

منابع رسمی مایکت:
<https://maven.myket.ir/services/android-sdk.html> ·
<https://maven.myket.ir/sdk-archives.csv>
