#!/usr/bin/env bash
# ساخت keystore رسمی برای ساین کردن APK/AAB فاکتور روبی
set -euo pipefail

cd "$(dirname "$0")"

STORE_FILE="upload-keystore.jks"
ALIAS="upload"
PROPS="key.properties"

if [[ -f "$STORE_FILE" ]]; then
  echo "❌ فایل $STORE_FILE از قبل وجود دارد. برای ساخت دوباره، اول آن را جابه‌جا/حذف کنید."
  exit 1
fi

echo "=============================================="
echo "  ساخت Keystore رسمی — فاکتور ساز روبی"
echo "=============================================="
echo ""
echo "رمزها را یادداشت کنید و در جای امن نگه دارید."
echo "اگر این keystore را گم کنید، دیگر نمی‌توانید همان اپ را در Play Store آپدیت کنید."
echo ""

read -r -s -p "Store password (رمز فایل): " STORE_PASS
echo ""
read -r -s -p "Key password  (رمز کلید، می‌تواند همان باشد): " KEY_PASS
echo ""
read -r -p "نام شما / شرکت (CN) [مثلا Kamand Beauty]: " CN
CN=${CN:-Kamand Beauty}
read -r -p "سازمان (O) [مثلا Kamand]: " O
O=${O:-Kamand}
read -r -p "شهر (L) [مثلا Tehran]: " L
L=${L:-Tehran}
read -r -p "استان (ST) [مثلا Tehran]: " ST
ST=${ST:-Tehran}
read -r -p "کشور دو حرفی (C) [IR]: " C
C=${C:-IR}

echo ""
echo "[1/2] در حال ساخت keystore..."
keytool -genkey -v \
  -keystore "$STORE_FILE" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$ALIAS" \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=$CN, OU=Mobile, O=$O, L=$L, ST=$ST, C=$C"

echo "[2/2] نوشتن key.properties..."
cat > "$PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$ALIAS
storeFile=$STORE_FILE
EOF

chmod 600 "$STORE_FILE" "$PROPS" 2>/dev/null || true

echo ""
echo "✅ آماده شد."
echo "  Keystore : android/$STORE_FILE"
echo "  Config   : android/$PROPS"
echo ""
echo "حالا از ریشه پروژه بسازید:"
echo "  flutter build apk --release"
echo "  flutter build appbundle --release   # برای Google Play"
echo ""
echo "خروجی APK:"
echo "  build/app/outputs/flutter-apk/app-release.apk"
echo "خروجی AAB (پیشنهادی برای پلی‌استور):"
echo "  build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "بررسی امضا:"
echo "  jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk"
echo "  keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk"
