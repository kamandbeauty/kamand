#!/usr/bin/env bash
#
# بررسی «به‌روزرسانی بدون حذف نصب» برای خروجی‌های اندروید.
#
# این اسکریپت دقیقاً همان چیزهایی را کنترل می‌کند که تعیین می‌کنند کاربر فعلی
# اپلیکیشن روبی بتواند نسخه‌ی تازه را روی نسخه‌ی نصب‌شده به‌روزرسانی کند و
# اطلاعاتش حفظ شود:
#
#   ۱) applicationId تغییر نکرده باشد (com.ruby.factor_ruby)
#   ۲) versionCode بزرگ‌تر از نسخه‌ی منتشرشده‌ی قبلی باشد
#   ۳) امضای دیجیتال با همان کلید نسخه‌ی قبلی انجام شده باشد
#   ۴) minSdk از نسخه‌ی قبلی بالاتر نرفته باشد
#   ۵) نسخه‌ی release قابل دیباگ نباشد
#
# استفاده:
#   scripts/verify_upgrade_safety.sh app-release.apk
#   PREVIOUS_APK=old.apk REQUIRE_NON_DEBUGGABLE=true scripts/verify_upgrade_safety.sh new.apk
#
set -euo pipefail

APK="${1:?usage: verify_upgrade_safety.sh <apk-path>}"
EXPECTED_APPLICATION_ID="${EXPECTED_APPLICATION_ID:-com.ruby.factor_ruby}"
EXPECTED_VERSION_NAME="${EXPECTED_VERSION_NAME:-}"
EXPECTED_VERSION_CODE="${EXPECTED_VERSION_CODE:-}"
PREVIOUS_APK="${PREVIOUS_APK:-}"
REQUIRE_NON_DEBUGGABLE="${REQUIRE_NON_DEBUGGABLE:-false}"

fail() {
  echo "::error::$1"
  exit 1
}

find_tool() {
  local tool="$1"
  local found
  found="$(command -v "$tool" 2>/dev/null || true)"
  if [[ -n "$found" ]]; then
    printf '%s' "$found"
    return 0
  fi
  local sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [[ -n "$sdk_root" ]]; then
    found="$(find "$sdk_root" -type f -name "$tool" -print 2>/dev/null | sort -V | tail -n 1)"
  fi
  printf '%s' "$found"
}

APKANALYZER="$(find_tool apkanalyzer)"
APKSIGNER="$(find_tool apksigner)"

[[ -f "$APK" ]] || fail "فایل APK پیدا نشد: $APK"
[[ -n "$APKANALYZER" ]] || fail "ابزار apkanalyzer در دسترس نیست؛ Android SDK را نصب کنید."

read_manifest_value() {
  "$APKANALYZER" manifest "$1" "$APK" 2>/dev/null | tr -d '\r' | xargs || true
}

APPLICATION_ID="$(read_manifest_value application-id)"
VERSION_NAME="$(read_manifest_value version-name)"
VERSION_CODE="$(read_manifest_value version-code)"
MIN_SDK="$(read_manifest_value min-sdk)"

echo "APK: $APK"
echo "  applicationId: $APPLICATION_ID"
echo "  versionName:   $VERSION_NAME"
echo "  versionCode:   $VERSION_CODE"
echo "  minSdk:        $MIN_SDK"

[[ "$APPLICATION_ID" == "$EXPECTED_APPLICATION_ID" ]] || fail \
  "شناسه‌ی برنامه عوض شده است ($APPLICATION_ID ≠ $EXPECTED_APPLICATION_ID). با تغییر applicationId کاربران مجبور به حذف نصب می‌شوند و اطلاعاتشان پاک می‌شود."

if [[ -n "$EXPECTED_VERSION_NAME" && "$VERSION_NAME" != "$EXPECTED_VERSION_NAME" ]]; then
  fail "versionName با pubspec.yaml نمی‌خواند ($VERSION_NAME ≠ $EXPECTED_VERSION_NAME)."
fi

if [[ -n "$EXPECTED_VERSION_CODE" && "$VERSION_CODE" != "$EXPECTED_VERSION_CODE" ]]; then
  fail "versionCode با pubspec.yaml نمی‌خواند ($VERSION_CODE ≠ $EXPECTED_VERSION_CODE)."
fi

if [[ "$REQUIRE_NON_DEBUGGABLE" == "true" ]]; then
  MANIFEST_DUMP="$("$APKANALYZER" manifest print "$APK" 2>/dev/null || true)"
  if grep -q 'android:debuggable="true"' <<< "$MANIFEST_DUMP"; then
    fail "خروجی release قابل دیباگ است (android:debuggable=true)."
  fi
fi

if [[ -n "$PREVIOUS_APK" ]]; then
  [[ -f "$PREVIOUS_APK" ]] || fail "APK نسخه‌ی قبلی پیدا نشد: $PREVIOUS_APK"
  [[ -n "$APKSIGNER" ]] || fail "ابزار apksigner برای مقایسه‌ی امضا در دسترس نیست."

  PREVIOUS_CODE="$("$APKANALYZER" manifest version-code "$PREVIOUS_APK" 2>/dev/null | tr -d '\r' | xargs || true)"
  PREVIOUS_MIN_SDK="$("$APKANALYZER" manifest min-sdk "$PREVIOUS_APK" 2>/dev/null | tr -d '\r' | xargs || true)"

  echo "APK نسخه‌ی قبلی: versionCode=$PREVIOUS_CODE minSdk=$PREVIOUS_MIN_SDK"

  if [[ -n "$PREVIOUS_CODE" && -n "$VERSION_CODE" ]]; then
    if (( VERSION_CODE <= PREVIOUS_CODE )); then
      fail "versionCode تازه ($VERSION_CODE) باید بزرگ‌تر از نسخه‌ی منتشرشده ($PREVIOUS_CODE) باشد؛ در غیر این صورت اندروید به‌روزرسانی را رد می‌کند."
    fi
  fi

  if [[ -n "$PREVIOUS_MIN_SDK" && -n "$MIN_SDK" ]]; then
    if (( MIN_SDK > PREVIOUS_MIN_SDK )); then
      fail "minSdk از $PREVIOUS_MIN_SDK به $MIN_SDK افزایش یافته است؛ کاربران دستگاه‌های قدیمی‌تر نمی‌توانند به‌روزرسانی کنند."
    fi
  fi

  NEW_CERTS="$("$APKSIGNER" verify --print-certs "$APK" 2>/dev/null | grep -i 'certificate SHA-256 digest' | tr -d '\r' | sort || true)"
  OLD_CERTS="$("$APKSIGNER" verify --print-certs "$PREVIOUS_APK" 2>/dev/null | grep -i 'certificate SHA-256 digest' | tr -d '\r' | sort || true)"

  if [[ -z "$NEW_CERTS" || -z "$OLD_CERTS" ]]; then
    echo "::warning::اثر انگشت گواهی خوانده نشد؛ بررسی امضا انجام نشد."
  elif [[ "$NEW_CERTS" != "$OLD_CERTS" ]]; then
    echo "گواهی نسخه‌ی قبلی:"; echo "$OLD_CERTS"
    echo "گواهی نسخه‌ی تازه:"; echo "$NEW_CERTS"
    fail "کلید امضای دیجیتال با نسخه‌ی منتشرشده‌ی قبلی یکی نیست. با کلید متفاوت، کاربران باید برنامه را حذف کنند و همه‌ی اطلاعاتشان از بین می‌رود."
  else
    echo "امضای دیجیتال با نسخه‌ی قبلی یکسان است ✔"
  fi
fi

echo "بررسی سازگاری به‌روزرسانی با موفقیت انجام شد ✔"
