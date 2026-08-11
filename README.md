# فاکتور روبی · Factor Ruby

**فاکتور روبی** یک ابزار فارسی و راست‌به‌چپ برای صدور فاکتور، نگه‌داری کاتالوگ کالا و خدمات، مدیریت مشتری و مانده‌حساب، و مشاهدهٔ جریان مالی کسب‌وکارهای کوچک است. این مخزن فقط شامل سورس Flutter اپلیکیشن موبایل اندروید و مستندات انتشار آن است.

> نسخهٔ فعلی: **۱.۰.۱** · شناسهٔ اندروید: `com.ruby.factor_ruby` · زبان رابط: فارسی

## آنچه در این مخزن وجود دارد

| بخش | مسیر | توضیح |
| --- | --- | --- |
| اپلیکیشن موبایل | `lib/` و `android/` | سورس Flutter/Dart با معماری لایه‌ای، Riverpod و طرح دیتابیس محلی Drift/SQLite |
| مستندات فنی | `ARCHITECTURE.md` و `DATABASE.md` | توضیح لایه‌ها، مدل داده و جداول محلی |

---

## امکانات فعلی

### شروع سریع و شخصی‌سازی اولیه

در اپ موبایل، فرایند شروع کار در پنج مرحله انجام می‌شود:

1. ثبت نام کاربر و خوش‌آمدگویی روبی
2. انتخاب واحد پول: تومان، ریال، دلار، یورو، دلار کانادا، لیر یا افغانی
3. انتخاب استان و شهر با جست‌وجوی شهرها
4. انتخاب نوع فعالیت؛ از فروشگاه و خدمات تا فریلنسری، عمده‌فروشی و استفادهٔ شخصی
5. تأیید اطلاعات و ورود به فضای کاری

### صدور و مدیریت فاکتور

- ایجاد **فاکتور فروش، فاکتور خرید و پیش‌فاکتور** با وضعیت نقدی یا غیرنقدی
- افزودن دستی سطرهای کالا/خدمت یا انتخاب آن‌ها از کاتالوگ
- محاسبهٔ خودکار مقدار × قیمت واحد، جمع اقلام و مبلغ نهایی
- اعمال تخفیف مبلغی یا درصدی، هزینهٔ ارسال، بیعانه و بدهی قبلی
- ثبت نام و شمارهٔ مشتری، تاریخ، شمارهٔ فاکتور، توضیحات و شمارهٔ کارت واریز
- مشاهدهٔ نسخهٔ قابل چاپ فاکتور همراه با ریز اقلام، جمع‌بندی پرداخت و جای امضا
- ساخت تصویر فاکتور، اشتراک‌گذاری از طریق Android Share Sheet و ذخیرهٔ تصویر در گالری
- ویرایش، حذف، کپی‌کردن فاکتور، تبدیل پیش‌فاکتور به فاکتور فروش و ثبت دریافت/تسویه
- زبانه‌های موقت برای جابه‌جایی میان چند فاکتور باز

### مشتریان و مانده‌حساب

- افزودن، ویرایش و حذف مشتری به‌همراه شماره تماس، آدرس، یادداشت و مانده‌حساب
- جست‌وجو بر اساس نام یا شمارهٔ تماس
- نمایش وضعیت «تسویه کامل» یا مبلغ بدهی هر مشتری
- ثبت دریافت از مشتری و به‌روزرسانی مانده‌حساب
- ساخت متن آمادهٔ یادآوری بدهی و کپی آن در کلیپ‌بورد
- دسترسی سریع به فاکتورهای ثبت‌شده برای هر مشتری

### کالاها و خدمات

- ساخت، ویرایش و حذف آیتم‌های کالا یا خدمت
- نگه‌داری نام، کد کالا، واحد، قیمت خرید، قیمت فروش، موجودی و توضیحات
- استفادهٔ مستقیم از کالاهای ثبت‌شده هنگام صدور فاکتور
- رابط آماده برای ایجاد دسته‌بندی و حالت خالی کاتالوگ

### داشبورد و گزارش مالی

- داشبورد با آمار فروش، دریافتی، بدهی مشتریان و تعداد فاکتورها
- فهرست فاکتورهای اخیر با وضعیت پرداخت و مبلغ نهایی
- ثبت درآمدهای متفرقه و هزینه‌های کسب‌وکار با دسته‌بندی
- محاسبهٔ مجموع درآمد، هزینه، بهای خرید، سود/زیان خالص تخمینی و بدهی‌ها در اپ موبایل

### تنظیمات کسب‌وکار

- ویرایش پروفایل کاربر و اطلاعات کسب‌وکار
- ثبت نام فروشگاه، شمارهٔ تماس، آدرس و شناسهٔ اقتصادی
- افزودن یا حذف شماره‌کارت‌های بانکی
- تنظیم شمارهٔ شروع فاکتور، قالب نمایش، نمایش لوگو و نمایش شماره‌کارت
- حالت روشن/تاریک و بازنشانی داده‌های نمونه در اپ موبایل

## راه‌اندازی Flutter و ساخت APK

### پیش‌نیازها

- Flutter SDK سازگار با Dart `>=3.2.0 <4.0.0`
- Android SDK و یک دستگاه یا شبیه‌ساز اندروید برای اجرا
- JDK 17 برای Android Gradle Plugin فعلی پروژه

```bash
# از ریشهٔ مخزن
flutter pub get
flutter run
```

راهنمای کامل ساخت، امضا و انتشار در بخش [راهنمای Release و انتشار](#راهنمای-release-و-انتشار) آمده است. برای بیلد معمولی Flutter:

```bash
flutter build apk --release --split-per-abi  # APKهای کم‌حجم برای هر معماری
flutter build appbundle --release # فرمت پیشنهادی Google Play
```

خروجی‌های استاندارد Flutter:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
build/app/outputs/bundle/release/app-release.aab
```

اسکریپت `build_apk.sh` فقط خروجی‌های واقعی Android را می‌سازد: APKهای جداشده بر اساس ABI و AAB. برای اجرای آن Flutter SDK و Android SDK باید در دسترس باشند.

---

## ساختار پروژه

```text
.
├── lib/
│   ├── core/                 # ثابت‌ها، تم، تاریخ شمسی و تبدیل اعداد فارسی
│   ├── database/             # تعریف جداول و اتصال Drift/SQLite
│   ├── models/               # مدل‌های کاربر، مشتری، کالا، فاکتور و مالی
│   ├── providers/            # مدیریت وضعیت با Riverpod
│   └── screens/              # صفحه‌های شروع، داشبورد، فاکتور، مشتری و تنظیمات
├── android/                  # پیکربندی اپلیکیشن اندروید و MainActivity
├── ARCHITECTURE.md           # معماری و فناوری‌های پروژه
├── DATABASE.md               # جزئیات جداول و روابط داده
└── build_apk.sh              # اسکریپت ساخت APK
```

---

## فناوری‌ها

| لایه | فناوری |
| --- | --- |
| اپ موبایل | Flutter و Dart |
| مدیریت وضعیت موبایل | `flutter_riverpod` |
| دادهٔ محلی موبایل | Drift، SQLite، `path_provider` |
| تقویم و قالب‌بندی فارسی | `shamsi_date`، `intl` و ابزارهای داخلی پروژه |

---

## مدل دادهٔ محلی

لایهٔ دیتابیس موبایل برای موجودیت‌های زیر طراحی شده است:

- کاربر و مشخصات کسب‌وکار
- مشتریان و مانده‌حساب
- کالاها و خدمات
- فاکتورها و اقلام فاکتور
- درآمدها و هزینه‌ها
- تنظیمات برنامه

برای نام ستون‌ها، روابط و جزئیات هر جدول به [DATABASE.md](DATABASE.md) مراجعه کنید. برای معماری، لایه‌ها و وابستگی‌ها نیز [ARCHITECTURE.md](ARCHITECTURE.md) را بخوانید.

---

## راهنمای Release و انتشار

این بخش برای آماده‌سازی نسخهٔ رسمی **فاکتور ساز روبی** در کافه‌بازار، مایکت و Google Play است. کلید خصوصی و رمز واقعی عمداً در این مخزن قرار نگرفته است.

### مشخصات Android Release

| مورد | مقدار فعلی |
| --- | --- |
| `applicationId` | `com.ruby.factor_ruby` |
| `namespace` | `com.ruby.factor_ruby` |
| `versionName` | `1.0.1` از `pubspec.yaml` |
| `versionCode` | `2` از `pubspec.yaml` (`1.0.1+2`) |
| Android Gradle Plugin | `8.11.1` |
| Gradle Wrapper | `8.14` |
| Kotlin | `2.2.20` |
| Java source/target و JDK CI | `17` |
| `compileSdk`، `targetSdk`، `minSdk` | از نسخهٔ Flutter (`flutter.compileSdkVersion`، `flutter.targetSdkVersion` و `flutter.minSdkVersion`)؛ عمداً hard-code نشده‌اند |
| Build Types | `debug` و `release` |
| Product Flavors | ندارد |
| R8/ProGuard و resource shrinking | غیرفعال؛ تا زمان تست کامل فعال نمی‌شوند |

`applicationId` فعلی معتبر و ثابت است و برای جلوگیری از ایجاد یک اپ جدید در بازارها تغییر داده نشده است. نسخه‌های بعدی باید `versionCode` بیشتری داشته باشند.

> مقادیر دقیق SDK نهایی را با همان Flutter SDK مورد استفاده برای Release بررسی کنید؛ این پروژه آن‌ها را به Flutter سپرده تا با ابزار رسمی Flutter سازگار بماند.

### پیش‌نیازها

- Android Studio و Android SDK با SDK Platform/Build Tools مناسب
- Flutter SDK سازگار با Dart `>=3.2.0 <4.0.0`
- JDK 17؛ برای بررسی: `java -version`
- Git و دسترسی به `keytool`، `jarsigner` و برای APK ابزار `apksigner`
- Gradle Wrapper داخل `android/`؛ نصب Gradle سراسری لازم نیست

پس از نصب Flutter، یک بار از ریشهٔ پروژه اجرا کنید:

```bash
flutter pub get
```

این دستور `android/local.properties` را با مسیر Flutter/Android SDK تنظیم می‌کند. این فایل ignored است و نباید commit شود. برای اجرای مستقیم Wrapper نیز می‌توان `FLUTTER_ROOT` را تنظیم کرد.

### ساخت Keystore رسمی

Keystore را بیرون از Repository بسازید؛ برای مثال:

```bash
mkdir -p "$HOME/.keys/factor-ruby"
keytool -genkeypair -v \
  -keystore "$HOME/.keys/factor-ruby/robi-release.jks" \
  -alias robi \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

`keytool` برای Store Password، Key Password و Distinguished Name سؤال می‌کند. نام فایل، alias، رمز فایل، رمز کلید و اطلاعات `CN/OU/O/L/ST/C` را با اطلاعات واقعی خودتان جایگزین کنید و هیچ‌کدام را در README یا Source قرار ندهید. اسکریپت تعاملی `android/create_keystore.sh` نیز همین کار را با نام پیش‌فرض `upload-keystore.jks` انجام می‌دهد:

```bash
cd android
chmod +x create_keystore.sh
./create_keystore.sh
```

Keystore اصلی، هر دو رمز، alias و Distinguished Name باید جدا از Repository و در چند محل امن و آفلاین Backup شوند. از دست دادن کلید می‌تواند امکان Update همان `applicationId` را در یک بازار از بین ببرد.

### پیکربندی Signing محلی

Gradle این چهار مقدار را به ترتیب از Environment Variables، فایل ignored `android/key.properties` و در آخر کلیدهای `release.*` در `android/local.properties` می‌خواند:

```text
RELEASE_STORE_FILE
RELEASE_STORE_PASSWORD
RELEASE_KEY_ALIAS
RELEASE_KEY_PASSWORD
```

**روش A — Environment Variables (پیشنهادی برای CI و قابل استفاده محلی):**

```bash
export RELEASE_STORE_FILE="$HOME/.keys/factor-ruby/robi-release.jks"
export RELEASE_STORE_PASSWORD='رمز-واقعی-خودتان'
export RELEASE_KEY_ALIAS='robi'
export RELEASE_KEY_PASSWORD='رمز-واقعی-کلید'
flutter build apk --release --split-per-abi
```

مقدار `RELEASE_STORE_FILE` می‌تواند مسیر مطلق باشد؛ مسیر نسبی نسبت به `android/` تفسیر می‌شود. فایل `.env.example` فقط نام متغیرها را نشان می‌دهد. اگر یک `.env` شخصی می‌سازید، آن را هرگز commit نکنید و پیش از Build آن را در Shell خود load کنید؛ Gradle خودش فایل `.env` را parse نمی‌کند.

**روش B — فایل محلی `android/key.properties`:**

```bash
cp android/key.properties.example android/key.properties
```

سپس مقادیر placeholder را فقط در همین فایل محلی عوض کنید:

```properties
storeFile=/مسیر/امن/robi-release.jks
storePassword=رمز_واقعی_فایل
keyAlias=robi
keyPassword=رمز_واقعی_کلید
```

`android/key.properties`، keystore و فایل‌های credential در `.gitignore` هستند؛ با این حال پیش از Commit حتماً `git status` و `git diff` را بررسی کنید.

**روش C — local.properties:**

اگر نمی‌خواهید `key.properties` بسازید، می‌توانید در فایل ignored `android/local.properties` این کلیدها را اضافه کنید. مقادیر موجود `sdk.dir` و `flutter.sdk` را حذف نکنید:

```properties
release.storeFile=/مسیر/امن/robi-release.jks
release.storePassword=رمز_واقعی_فایل
release.keyAlias=robi
release.keyPassword=رمز_واقعی_کلید
```

برای جلوگیری از پخش شدن رمزها، Environment Variables یا `key.properties` محلی ترجیح دارد.

**Windows CMD:**

```cmd
set RELEASE_STORE_FILE=C:\Users\YOUR_NAME\secure\robi-release.jks
set RELEASE_STORE_PASSWORD=YOUR_STORE_PASSWORD
set RELEASE_KEY_ALIAS=robi
set RELEASE_KEY_PASSWORD=YOUR_KEY_PASSWORD
flutter build apk --release --split-per-abi
```

**Windows PowerShell:**

```powershell
$env:RELEASE_STORE_FILE = "C:\Users\YOUR_NAME\secure\robi-release.jks"
$env:RELEASE_STORE_PASSWORD = "YOUR_STORE_PASSWORD"
$env:RELEASE_KEY_ALIAS = "robi"
$env:RELEASE_KEY_PASSWORD = "YOUR_KEY_PASSWORD"
flutter build apk --release --split-per-abi
```

رمز واقعی را در Documentation، History، commandهای commit یا Log قرار ندهید.

### Build Debug بدون Keystore Release

Debug به Release Keystore وابسته نیست و باید بعد از `flutter pub get` بدون هیچ Secretای کار کند:

```bash
flutter build apk --debug

# یا با Gradle Wrapper از پوشهٔ android
cd android
./gradlew assembleDebug
```

در Windows:

```powershell
cd android
.\\gradlew.bat assembleDebug
```

### ساخت Release APK

پس از پیکربندی Signing:

```bash
# از ریشهٔ پروژه
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```

این فرمان برای هر معماری یک APK جدا و کوچک‌تر تولید می‌کند. برای خروجی واحد با Wrapper استاندارد پروژه:

```bash
cd android
./gradlew clean
./gradlew assembleRelease
```

برای حجم کمتر، فرمان Flutter با `--split-per-abi` و اسکریپت `build_apk.sh` را ترجیح دهید. خروجی Wrapper واحد در مسیر Gradle قرار می‌گیرد:

```text
build/app/outputs/apk/release/app-release.apk
```

خروجی APKهای کم‌حجم:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

برای کافه‌بازار و مایکت، APK رسمی Signed با معماری موردنیاز پنل را انتخاب کنید؛ `arm64-v8a` معمولاً گزینهٔ کوچک‌تر برای گوشی‌های جدید است. APK دیباگ یا نسخه‌ای که با Debug Key امضا شده قابل انتشار نیست.

### ساخت Release AAB برای Google Play

Google Play معمولاً فرمت Android App Bundle را برای انتشار اصلی می‌خواهد:

```bash
# از ریشهٔ پروژه
flutter build appbundle --release

# یا از android/
cd android
./gradlew bundleRelease
```

خروجی استاندارد:

```text
build/app/outputs/bundle/release/app-release.aab
```

### بررسی امضا و اطلاعات بسته

برای APK، ابزار `apksigner` را از Android SDK Build Tools پیدا کنید:

```bash
apksigner verify --verbose build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

در صورت تولید چند ABI، همین بررسی را برای APK انتخابی انتشار انجام دهید. باید در خروجی تأیید معتبر بودن امضا را ببینید. برای AAB که یک JAR امضاشده است:

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab

keytool -printcert -jarfile build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

برای بررسی شناسه و نسخه، در صورت نصب بودن Android SDK Command-line Tools:

```bash
apkanalyzer manifest application-id build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
apkanalyzer manifest version-name build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
apkanalyzer manifest version-code build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

مقادیر مورد انتظار این نسخه `com.ruby.factor_ruby`، `1.0.1` و `2` هستند و Release نباید `debuggable=true` داشته باشد. `apksigner` امضای APK و `jarsigner` امضای AAB را بررسی می‌کنند؛ این دو را با صرفاً نصب شدن فایل اشتباه نگیرید.

### GitHub Actions و Secrets

Workflow رسمی در `.github/workflows/release.yml` قرار دارد و روی Tagهای `v*.*.*` یا `release-*` و همچنین `workflow_dispatch` اجرا می‌شود. Workflow:

1. Java 17 و Flutter stable را آماده می‌کند؛
2. چهار Secret زیر را بررسی می‌کند؛
3. keystore Base64 را در یک فایل موقت خارج از Repository Decode می‌کند؛
4. از Gradle Wrapper فرمان‌های `./gradlew clean`، `./gradlew assembleRelease` و `./gradlew bundleRelease` را اجرا می‌کند؛
5. APK و AAB Signed می‌سازد؛
6. با `apksigner` و `jarsigner` امضا را Verify می‌کند و در صورت موجود بودن `apkanalyzer`، شناسه/نسخه/debuggable را نیز بررسی می‌کند؛
7. Artifactهای نام‌گذاری‌شده را Upload می‌کند؛
8. برای Tag، APK و AAB را به GitHub Release همان Tag Attach می‌کند؛
9. فایل keystore موقت را در پایان حذف می‌کند.

Secretهای لازم در Settings → Secrets and variables → Actions:

- `RELEASE_KEYSTORE_BASE64`
- `RELEASE_STORE_PASSWORD`
- `RELEASE_KEY_ALIAS`
- `RELEASE_KEY_PASSWORD`

`RELEASE_STORE_FILE` برای CI لازم نیست؛ Workflow مسیر موقت را خودش به Gradle می‌دهد. Base64 فقط وسیلهٔ انتقال رمزگذاری‌نشدهٔ محتوای باینری در Secret Store است و جایگزین Backup امن keystore نیست. Workflow هیچ‌کدام از Secretها را `echo` یا dump نمی‌کند.

### تبدیل Keystore به Base64

**Linux:**

```bash
base64 -w 0 "$HOME/.keys/factor-ruby/robi-release.jks" \
  > "$HOME/.keys/factor-ruby/robi-release.jks.base64"
```

**macOS:**

```bash
base64 "$HOME/.keys/factor-ruby/robi-release.jks" | tr -d '\\n' \
  > "$HOME/.keys/factor-ruby/robi-release.jks.base64"
```

**Windows PowerShell:**

```powershell
[IO.File]::WriteAllText(
  "robi-release.jks.base64",
  [Convert]::ToBase64String([IO.File]::ReadAllBytes("robi-release.jks"))
)
```

محتوای فایل `.base64` را به‌عنوان Secret با نام دقیق `RELEASE_KEYSTORE_BASE64` در GitHub ذخیره کنید. فایل `.base64` نیز در `.gitignore` است و نباید به Repository، Issue، Log یا Release Asset وارد شود.

### ساخت Tag و GitHub Release

پس از اطمینان از افزایش version در `pubspec.yaml` و تنظیم چهار Secret:

```bash
git tag -a v1.0.1 -m "فاکتور ساز روبی 1.0.1"
git push origin v1.0.1
```

Workflow برای Tag اجرا می‌شود و خروجی‌های زیر را می‌سازد (نسخه و versionCode از `pubspec.yaml` خوانده می‌شود):

```text
RubiFactor-v1.0.1-vc2-arm64-v8a-release.apk
RubiFactor-v1.0.1-vc2-armeabi-v7a-release.apk
RubiFactor-v1.0.1-vc2-x86_64-release.apk
RubiFactor-v1.0.1-vc2-release.aab
```

قبل از Tag نسخهٔ جدید، `versionCode` را افزایش دهید؛ Google Play و بازارها Update را با version code پایین‌تر نمی‌پذیرند.

### Google Play

- خروجی اصلی برای Google Play، **AAB** است.
- هنگام اولین انتشار، Play App Signing را در Play Console در نظر بگیرید. `Upload Key` کلیدی است که شما برای ارسال Update نگه می‌دارید؛ `App Signing Key` کلیدی است که Google برای امضای نسخهٔ توزیع‌شده مدیریت می‌کند.
- اگر این اپ قبلاً در Play یا بازار دیگری منتشر شده، بدون دلیل کلید انتشار/Upload Key یا `applicationId` را تغییر ندهید.
- الزامات فعلی Google Play، target SDK، محتوای Store و Play Console را در پنل رسمی همان زمان بررسی کنید؛ این README جای قوانین به‌روز فروشگاه نیست.

### کافه‌بازار

- به‌صورت پیش‌فرض Release APK را آماده کنید، مگر اینکه پنل رسمی بازار در زمان انتشار فرمت دیگری بخواهد.
- APK باید با Release Keystore امضای معتبر داشته باشد؛ Debug APK قابل انتشار نیست.
- `applicationId` باید در تمام Updateها ثابت بماند و همان کلید سازگار با نسخهٔ قبلی استفاده شود.
- برای هر Update، `versionCode` را افزایش دهید.
- قوانین، محدودیت حجم، الزامات محتوا و فرمت‌های فعلی را فقط از پنل/مستندات رسمی کافه‌بازار در زمان انتشار Verify کنید؛ این پروژه دربارهٔ Policy فعلی بازار حدس نمی‌زند.

### مایکت

- Release APK را بسازید و همان فایل رسمی امضاشده را آپلود کنید، نه Debug APK.
- `applicationId` ثابت و Release Keystore سازگار با نسخهٔ منتشرشدهٔ قبلی باشد.
- `versionCode` هر Update باید افزایش پیدا کند.
- قوانین فعلی فایل، target SDK، محتوا و انتشار را با Console/مستندات رسمی مایکت در زمان آپلود بررسی کنید؛ اطلاعات قدیمی به‌عنوان Policy قطعی در این پروژه اعلام نمی‌شود.

### Signing ≠ Google Trust

**Signed APK** یعنی فایل دارای امضای دیجیتال معتبر است و Android می‌تواند تمامیت فایل و مالکیت کلید انتشار را بررسی کند. Signed بودن به این معنی نیست که Google Play Protect یا Android آن را خودکار یک برنامهٔ شناخته‌شده و trusted تشخیص می‌دهد. نصب APK خارج از Google Play، به‌خصوص برای برنامهٔ جدید، ممکن است هشدار منبع ناشناس یا هشدار امنیتی نشان دهد. برای اعتماد و توزیع رسمی Google Play باید AAB، Play App Signing، انتشار رسمی و الزامات فعلی Google Play رعایت شود.

### چک‌لیست امنیت و انتشار

- `android/key.properties`، keystore، `.p12`، `.pem`، `.base64`، `.env` و رمزها در Git نیستند.
- Release بدون چهار مقدار Signing به‌صورت عمدی با debug key جایگزین نمی‌شود و با خطای واضح متوقف می‌شود.
- Debug به Release Keystore وابسته نیست.
- `minifyEnabled` و `shrinkResources` تا تست کامل عمداً خاموش هستند؛ ProGuard/R8 بدون تست فعال نشده است.
- APK با `apksigner verify --verbose` و AAB با `jarsigner -verify` بررسی شده‌اند.
- Keystore اصلی، Backupها، Store Password، Key Password و alias در Password Manager/محل امن نگه‌داری می‌شوند.
- قبل از هر Commit این بررسی‌ها انجام می‌شود:

```bash
git status --short
git diff --check
git diff -- .
git ls-files | grep -E '\.(jks|keystore|p12|pem|base64)$' || true
```

اگر فایل keystore یا Secret واقعی در Git قرار گرفت، صرفاً حذف فایل کافی نیست؛ کلید باید در نظر گرفته‌شده و در صورت لزوم تعویض شود و History نیز پاک‌سازی شود.

---

## مشارکت

1. یک شاخهٔ کاری بسازید.
2. تغییرات را با رابط فارسی و حالت راست‌به‌چپ آزمایش کنید.
3. برای تغییرات موبایل، Build و تست Android را اجرا کنید.
4. تغییرات و علت آن‌ها را در Pull Request توضیح دهید.

---

فاکتور روبی برای ساده‌تر کردن ثبت فروش، پیگیری بدهی و دیدن وضعیت مالی روزانهٔ کسب‌وکار طراحی شده است.
