# امضای رسمی APK / AAB — فاکتور ساز روبی

## چرا گوگل/اندروید می‌گوید «ناشناخته»؟

الان در `android/app/build.gradle.kts` نسخهٔ **release** با کلید **debug** ساین می‌شد.  
کلید debug فقط برای توسعه است و سیستم‌عامل آن را به‌عنوان اپ ناشناس/غیررسمی می‌شناسد.

برای نصب عادی روی گوشی و انتشار در **Google Play** باید با یک **keystore دائمی** ساین کنید.

---

## روش سریع (پیشنهادی)

### ۱) ساخت keystore (فقط یک‌بار)

```bash
cd android
chmod +x create_keystore.sh
./create_keystore.sh
```

یا دستی:

```bash
cd android
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

سپس فایل `android/key.properties` را بسازید:

```properties
storePassword=رمز_فایل
keyPassword=رمز_کلید
keyAlias=upload
storeFile=upload-keystore.jks
```

> مسیر `storeFile` نسبت به پوشهٔ `android/app` است.  
> اگر jks را در `android/` گذاشته‌اید، بنویسید: `storeFile=../upload-keystore.jks`  
> اسکریپت `create_keystore.sh` به‌صورت پیش‌فرض jks را کنار `key.properties` در `android/` می‌سازد و `storeFile=upload-keystore.jks` می‌نویسد — در `build.gradle.kts` مسیر نسبت به `android/app` اصلاح شده است.

### ۲) بیلد release امضاشده

```bash
# از ریشه پروژه
flutter clean
flutter pub get
flutter build apk --release
```

خروجی:

```text
build/app/outputs/flutter-apk/app-release.apk
```

برای **Google Play** بهتر است AAB بسازید:

```bash
flutter build appbundle --release
```

خروجی:

```text
build/app/outputs/bundle/release/app-release.aab
```

### ۳) بررسی امضا

```bash
# باید signer غیر از Android Debug باشد
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk | head -30

jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk | tail -20
```

اگر `CN=Android Debug` دیدید، هنوز با debug ساین شده.

---

## Google Play Console

1. یک بار keystore را بسازید و **بکاپ** بگیرید (جای امن + رمزها).
2. در Play Console → App integrity:
   - یا **Play App Signing** را فعال کنید و فقط **upload key** را خودتان نگه دارید (پیشنهادی).
   - یا خودتان app signing key را مدیریت کنید.
3. هر آپدیت بعدی باید با **همان upload key** ساین شود.

### اگر keystore را گم کنید

- دیگر نمی‌توانید همان `applicationId` (`com.ruby.factor_ruby`) را در Play به‌روز کنید.
- باید اپ جدید با package name جدید منتشر کنید.

---

## امنیت

| فایل | Git |
| --- | --- |
| `android/upload-keystore.jks` | ❌ هرگز commit نشود |
| `android/key.properties` | ❌ هرگز commit نشود |
| `android/key.properties.example` | ✅ بدون رمز واقعی |

در CI (GitHub Actions) رمزها را در **Secrets** بگذارید و در workflow فایل `key.properties` را بسازید.

---

## نصب روی گوشی

بعد از ساین release:

1. APK قبلی (debug) را uninstall کنید (چون signature فرق دارد).
2. APK جدید release را نصب کنید.
3. اگر باز هم «منبع ناشناس» آمد: فقط هشدار نصب از خارج Play است — با «نصب» تأیید کنید. این با «امضای debug» فرق دارد.
