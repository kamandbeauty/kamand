#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  انتخاب خودکار میرور سالم برای دانلود توزیع Gradle
#
#  این اسکریپت آدرس‌های مختلف را تست می‌کند و اولین آدرسی که واقعاً پاسخ
#  می‌دهد را در gradle/wrapper/gradle-wrapper.properties می‌نویسد.
#
#  استفاده:
#      bash scripts/pick-gradle-mirror.sh
#      bash scripts/pick-gradle-mirror.sh 8.9      # نسخهٔ دلخواه
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

VERSION="${1:-8.10.2}"
PROPS="$(dirname "$0")/../gradle/wrapper/gradle-wrapper.properties"

CANDIDATES=(
  "https://download.jamko.ir/gradle-distributions/gradle-${VERSION}-bin.zip"
  "https://mirror.kargadan.ir/gradle/distributions/gradle-${VERSION}-bin.zip"
  "https://archive.ito.gov.ir/gradle/distributions/gradle-${VERSION}-bin.zip"
  "https://services.gradle.org/distributions/gradle-${VERSION}-bin.zip"
)

echo "در حال تست میرورها برای Gradle ${VERSION} ..."
echo

FOUND=""
for url in "${CANDIDATES[@]}"; do
  printf '  %-72s ' "${url}"
  code=$(curl -s -o /dev/null -w '%{http_code}' -I -L --max-time 15 "${url}" 2>/dev/null || echo "000")
  if [[ "${code}" == "200" ]]; then
    echo "✅ ${code}"
    [[ -z "${FOUND}" ]] && FOUND="${url}"
  else
    echo "❌ ${code}"
  fi
done

echo
if [[ -z "${FOUND}" ]]; then
  echo "هیچ میروری پاسخ نداد."
  echo
  echo "راه‌حل جایگزین: اگر Gradle روی سیستم نصب است، اصلاً نیازی به دانلود نیست:"
  echo "    gradle wrapper --gradle-version ${VERSION}"
  exit 1
fi

# کاراکتر : در فرمت properties باید escape شود
ESCAPED="${FOUND/:\/\//\\://}"
if [[ -f "${PROPS}" ]]; then
  sed -i.bak "s|^distributionUrl=.*|distributionUrl=${ESCAPED}|" "${PROPS}"
  echo "✅ تنظیم شد روی: ${FOUND}"
  echo "   (نسخهٔ پشتیبان: ${PROPS}.bak)"
  echo
  echo "حالا اجرا کنید:  ./gradlew :app:assembleDebug"
else
  echo "فایل ${PROPS} پیدا نشد. آدرس سالم:"
  echo "    ${FOUND}"
fi
