#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  انتخاب خودکار میرور سالم برای دانلود توزیع Gradle
#
#  آدرس‌ها را تست می‌کند و اولین آدرسی که واقعاً پاسخ می‌دهد را در
#  gradle/wrapper/gradle-wrapper.properties می‌نویسد.
#
#  استفاده:
#      bash scripts/pick-gradle-mirror.sh          # نسخهٔ پیش‌فرض 8.10.2
#      bash scripts/pick-gradle-mirror.sh 8.13     # نسخهٔ دلخواه
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

VERSION="${1:-8.10.2}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROPS="${SCRIPT_DIR}/../gradle/wrapper/gradle-wrapper.properties"

# ترتیب = اولویت. مایکت اول چون مستندات رسمی دارد و داخل ایران میزبانی می‌شود.
CANDIDATES=(
  "https://maven.myket.ir/gradle/distributions/gradle-${VERSION}-bin.zip"
  "https://mirror.kargadan.ir/gradle/distributions/gradle-${VERSION}-bin.zip"
  "https://archive.ito.gov.ir/gradle/distributions/gradle-${VERSION}-bin.zip"
  "https://services.gradle.org/distributions/gradle-${VERSION}-bin.zip"
)

echo "تست میرورها برای Gradle ${VERSION} ..."
echo

FOUND=""
for url in "${CANDIDATES[@]}"; do
  printf '  %-68s ' "${url}"
  code=$(curl -s -o /dev/null -w '%{http_code}' -I -L --max-time 20 "${url}" 2>/dev/null || echo "000")
  case "${code}" in
    200) echo "✅ موجود"; [[ -z "${FOUND}" ]] && FOUND="${url}" ;;
    000) echo "❌ عدم دسترسی/تایم‌اوت" ;;
    *)   echo "❌ HTTP ${code}" ;;
  esac
done

echo
if [[ -z "${FOUND}" ]]; then
  echo "هیچ میروری پاسخ نداد."
  echo
  echo "گزینه‌های جایگزین:"
  echo "  • نسخهٔ دیگری را امتحان کنید:   bash $0 8.13"
  echo "  • اگر Gradle نصب دارید:        gradle wrapper --gradle-version ${VERSION}"
  echo "  • یا پروژه را در Android Studio باز کنید (Gradle داخلی دارد)"
  exit 1
fi

# در فرمت properties کاراکتر ':' باید escape شود
ESCAPED="${FOUND/:\/\//\\://}"
if [[ -f "${PROPS}" ]]; then
  cp "${PROPS}" "${PROPS}.bak"
  sed -i "s|^distributionUrl=.*|distributionUrl=${ESCAPED}|" "${PROPS}"
  echo "✅ تنظیم شد: ${FOUND}"
  echo "   پشتیبان: ${PROPS}.bak"
  echo
  echo "حالا اجرا کنید:  ./gradlew :app:assembleDebug"
else
  echo "فایل properties پیدا نشد. آدرس سالم:"
  echo "    ${FOUND}"
fi
