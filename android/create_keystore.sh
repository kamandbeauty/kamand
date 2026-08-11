#!/usr/bin/env bash
# ساخت keystore رسمی برای ساین کردن APK/AAB فاکتور ساز روبی
set -euo pipefail

cd "$(dirname "$0")"

STORE_FILE="upload-keystore.jks"
ALIAS="upload"
PROPS="key.properties"

if [[ -e "$STORE_FILE" ]]; then
  echo "❌ فایل $STORE_FILE از قبل وجود دارد. برای ساخت دوباره، آن را به محل امن منتقل کنید."
  exit 1
fi

cat <<'BANNER'
==============================================
  ساخت Keystore رسمی — فاکتور ساز روبی
==============================================

این فایل و رمزهای آن را در محل امن نگه دارید و چند Backup آفلاین بگیرید.
Keystore واقعی نباید وارد Git یا هیچ مخزن عمومی شود.
BANNER

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
echo "[1/2] در حال ساخت keystore با RSA-4096..."
keytool -genkeypair -v \
  -keystore "$STORE_FILE" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=$CN, OU=Mobile, O=$O, L=$L, ST=$ST, C=$C"

echo "[2/2] نوشتن android/key.properties..."
umask 077
cat > "$PROPS" <<EOF
storeFile=$STORE_FILE
storePassword=$STORE_PASS
keyAlias=$ALIAS
keyPassword=$KEY_PASS
EOF

chmod 600 "$STORE_FILE" "$PROPS" 2>/dev/null || true

cat <<EOF

✅ آماده شد.
  Keystore : android/$STORE_FILE
  Config   : android/$PROPS

از ریشه پروژه بسازید:
  flutter build apk --release
  flutter build appbundle --release   # خروجی پیشنهادی Google Play

خروجی APK : build/app/outputs/flutter-apk/app-release.apk
خروجی AAB : build/app/outputs/bundle/release/app-release.aab

بررسی امضا:
  apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
  jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
EOF
