#!/usr/bin/env bash

# ساخت خروجی‌های واقعی اندروید فاکتور ساز روبی
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "=========================================="
echo "  فاکتور ساز روبی - ساخت خروجی Android"
echo "=========================================="

if ! command -v flutter >/dev/null 2>&1; then
  echo "خطا: Flutter SDK در PATH پیدا نشد."
  echo "برای ساخت APK/AAB واقعی، Flutter و Android SDK را نصب و دوباره اجرا کنید."
  exit 1
fi

flutter --version | head -n 1
echo "[1/3] دریافت وابستگی‌ها..."
flutter pub get

echo "[2/3] ساخت APKهای کم‌حجم جداشده بر اساس ABI..."
flutter build apk --release --split-per-abi

echo "[3/3] ساخت AAB برای Google Play..."
flutter build appbundle --release

echo ""
echo "✅ خروجی‌ها آماده شدند:"
find build/app/outputs/flutter-apk -maxdepth 1 -type f -name '*release.apk' -print | sort
printf '%s\n' "build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "برای انتشار APK، فایل ABI مناسب دستگاه‌ها را انتخاب کنید."
echo "برای Google Play، AAB را استفاده کنید."
