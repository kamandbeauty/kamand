# راهنمای Signing و انتشار — فاکتور ساز روبی

این فایل خلاصهٔ عملی راهنمای کامل [README](README.md#راهنمای-release-و-انتشار) است. هیچ keystore یا رمز واقعی در Repository قرار ندارد.

## مشخصات Release فعلی

- `applicationId` و `namespace`: `com.ruby.factor_ruby`
- `versionName`: `1.0.1`
- `versionCode`: `2`
- Android Gradle Plugin: `8.11.1`
- Gradle Wrapper: `8.14`
- Kotlin: `2.2.20`
- Java/JDK: `17`
- Build Types: `debug` و `release`؛ Product Flavor وجود ندارد
- `minifyEnabled` و `shrinkResources`: خاموش و بدون تست فعال نمی‌شوند

`compileSdk`، `targetSdk` و `minSdk` از Flutter SDK جاری خوانده می‌شوند. این پروژه applicationId معتبر موجود را تغییر نداده است.

## سیاست Signing

`android/app/build.gradle.kts` مقدارهای زیر را از Environment Variables یا فایل‌های محلی ignored می‌خواند:

```text
RELEASE_STORE_FILE
RELEASE_STORE_PASSWORD
RELEASE_KEY_ALIAS
RELEASE_KEY_PASSWORD
```

برای Local، `android/key.properties` با کلیدهای `storeFile`، `storePassword`، `keyAlias` و `keyPassword` نیز پشتیبانی می‌شود. فایل `android/local.properties` هم می‌تواند همین مقدارها را با پیشوند `release.` داشته باشد. اولویت با Environment Variables است.

- `assembleDebug` و `flutter build apk --debug` به Release Keystore نیاز ندارند.
- `assembleRelease` و `bundleRelease` بدون Signing معتبر عمداً با پیام `Release signing credentials are not configured` متوقف می‌شوند.
- Release هرگز به‌صورت بی‌صدا با Debug Key امضا نمی‌شود.
- رمزها در Gradle script hard-code یا چاپ نمی‌شوند.

## ساخت Keystore

Keystore را خارج از مخزن و در محل امن بسازید:

```bash
mkdir -p "$HOME/.keys/factor-ruby"
keytool -genkeypair -v \
  -keystore "$HOME/.keys/factor-ruby/robi-release.jks" \
  -alias robi \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

نام فایل، alias، رمز Store، رمز Key و Distinguished Name را با اطلاعات واقعی خودتان جایگزین کنید. رمزها هنگام اجرای `keytool` پرسیده می‌شوند؛ آن‌ها را در README، Source یا Git ننویسید.

اسکریپت تعاملی پروژه نیز قابل استفاده است:

```bash
cd android
chmod +x create_keystore.sh
./create_keystore.sh
```

از Keystore اصلی، هر دو Password و alias چند Backup امن و آفلاین بگیرید. برای Update یک اپ منتشرشده، همان کلید سازگار لازم است.

## تنظیم Local Signing

### با Environment Variables

Linux/macOS:

```bash
export RELEASE_STORE_FILE="$HOME/.keys/factor-ruby/robi-release.jks"
export RELEASE_STORE_PASSWORD='YOUR_STORE_PASSWORD'
export RELEASE_KEY_ALIAS='robi'
export RELEASE_KEY_PASSWORD='YOUR_KEY_PASSWORD'
```

Windows CMD:

```cmd
set RELEASE_STORE_FILE=C:\Users\YOUR_NAME\secure\robi-release.jks
set RELEASE_STORE_PASSWORD=YOUR_STORE_PASSWORD
set RELEASE_KEY_ALIAS=robi
set RELEASE_KEY_PASSWORD=YOUR_KEY_PASSWORD
```

Windows PowerShell:

```powershell
$env:RELEASE_STORE_FILE = "C:\Users\YOUR_NAME\secure\robi-release.jks"
$env:RELEASE_STORE_PASSWORD = "YOUR_STORE_PASSWORD"
$env:RELEASE_KEY_ALIAS = "robi"
$env:RELEASE_KEY_PASSWORD = "YOUR_KEY_PASSWORD"
```

### با `android/key.properties`

```bash
cp android/key.properties.example android/key.properties
```

فقط در فایل محلی مقدارها را تکمیل کنید:

```properties
storeFile=/absolute/path/to/robi-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=robi
keyPassword=YOUR_KEY_PASSWORD
```

مسیر نسبی `storeFile` نسبت به پوشهٔ `android/` است. `android/key.properties` و فایل‌های keystore در `.gitignore` هستند، ولی قبل از Commit همیشه `git status` را بررسی کنید.

نام متغیرها در `.env.example` نیز برای کپی‌برداری مشخص شده است. Gradle فایل `.env` را خودکار load نمی‌کند؛ اگر `.env` شخصی می‌سازید، آن را در Shell خود load کنید و هرگز commit نکنید.

## Build

اول از ریشهٔ پروژه:

```bash
flutter pub get
```

Debug بدون Release Keystore:

```bash
flutter build apk --debug
# یا
cd android && ./gradlew assembleDebug
```

Release APK برای کافه‌بازار و مایکت:

```bash
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
# یا برای خروجی واحد با Gradle از android/
./gradlew assembleRelease
```

خروجی APKهای کم‌حجم:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

برای انتشار APK، معماری مناسب را بر اساس نیاز بازار/دستگاه انتخاب کنید. `arm64-v8a` معمولاً گزینهٔ اصلی کوچک‌تر برای گوشی‌های جدید است. خروجی واحد Gradle در مسیر زیر قرار می‌گیرد:

```text
build/app/outputs/apk/release/app-release.apk
```

Release AAB برای Google Play:

```bash
flutter build appbundle --release
# یا از android/
./gradlew bundleRelease
```

خروجی:

```text
build/app/outputs/bundle/release/app-release.aab
```

در Windows به جای `./gradlew` از `gradlew.bat` استفاده کنید.

## Verify

```bash
apksigner verify --verbose build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

برای اطلاعات بسته، در صورت نصب بودن `apkanalyzer`:

```bash
apkanalyzer manifest application-id build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
apkanalyzer manifest version-name build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
apkanalyzer manifest version-code build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

باید applicationId برابر `com.ruby.factor_ruby`، versionName برابر `1.0.1` و versionCode برابر `2` باشد و Release debuggable نباشد.

## GitHub Actions

Workflow در `.github/workflows/release.yml` روی Tagهای `v*.*.*`/`release-*` و اجرای دستی فعال است. چهار GitHub Secret زیر را بسازید:

- `RELEASE_KEYSTORE_BASE64`
- `RELEASE_STORE_PASSWORD`
- `RELEASE_KEY_ALIAS`
- `RELEASE_KEY_PASSWORD`

Workflow Base64 را Decode می‌کند، keystore را در `$RUNNER_TEMP` می‌سازد، با Gradle Wrapper فرمان‌های `./gradlew clean`، `./gradlew assembleRelease` و `./gradlew bundleRelease` را اجرا می‌کند، APK و AAB را Verify می‌کند، Artifact آپلود می‌کند و برای Tag یک GitHub Release می‌سازد. در پایان فایل موقت حذف می‌شود و هیچ Secretای در Log چاپ نمی‌شود.

ساخت Base64:

```bash
# Linux
base64 -w 0 robi-release.jks > robi-release.jks.base64

# macOS
base64 robi-release.jks | tr -d '\n' > robi-release.jks.base64
```

Windows PowerShell:

```powershell
[IO.File]::WriteAllText(
  "robi-release.jks.base64",
  [Convert]::ToBase64String([IO.File]::ReadAllBytes("robi-release.jks"))
)
```

محتوای خروجی را فقط به‌عنوان `RELEASE_KEYSTORE_BASE64` در GitHub Secret ذخیره کنید. فایل keystore، Base64 و Password نباید در Repository یا Release Asset قرار گیرند.

برای اجرای Release با Tag:

```bash
git tag -a v1.0.1 -m "فاکتور ساز روبی 1.0.1"
git push origin v1.0.1
```

## مقصدهای انتشار

- **Google Play:** AAB خروجی اصلی است. Play App Signing و تفاوت Upload Key/App Signing Key را در Play Console بررسی کنید. قوانین فعلی Google را در Console رسمی بررسی کنید.
- **کافه‌بازار:** معمولاً Release APK را آماده کنید، مگر پنل رسمی فرمت دیگری بخواهد. applicationId و کلید سازگار و versionCode افزایشی لازم است. Policy فعلی را از پنل رسمی Verify کنید.
- **مایکت:** Release APK امضاشده را استفاده کنید، نه Debug APK. applicationId و کلید را ثابت نگه دارید و versionCode را افزایش دهید. Policy فعلی را از Console رسمی Verify کنید.

**Signing ≠ Google Trust:** Signed بودن فقط یعنی امضای دیجیتال معتبر است؛ تضمین نمی‌کند APK خارج از Google Play بدون هشدار «منبع ناشناس» یا هشدارهای Play Protect نصب شود. برای توزیع رسمی Google Play، AAB، Play App Signing و الزامات روز Google Play را رعایت کنید.
