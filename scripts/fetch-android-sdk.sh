#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  دانلود و نصب دستی Android SDK از میرور مایکت
#
#  چرا لازم است؟
#  Android Studio پکیج‌های SDK را از dl.google.com می‌گیرد که در ایران مسدود
#  است. مایکت سرویس خودکار SDK ندارد، اما یک فایل CSV با لینک مستقیم همهٔ
#  پکیج‌ها ارائه می‌دهد. این اسکریپت پکیج‌های موردنیاز همین پروژه را از آن
#  CSV پیدا، دانلود و در مسیر درست extract می‌کند.
#
#  استفاده:
#      bash scripts/fetch-android-sdk.sh                 # دانلود + نصب
#      bash scripts/fetch-android-sdk.sh --list          # فقط نمایش لینک‌ها
#
#  مرجع: https://maven.myket.ir/services/android-sdk.html
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

CSV_URL="https://maven.myket.ir/sdk-archives.csv"
LIST_ONLY=0
[[ "${1:-}" == "--list" ]] && LIST_ONLY=1

# ── تشخیص مسیر SDK ───────────────────────────────────────────────────────────
detect_sdk_root() {
  if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then echo "${ANDROID_SDK_ROOT}"; return; fi
  if [[ -n "${ANDROID_HOME:-}" ]];     then echo "${ANDROID_HOME}";     return; fi
  case "$(uname -s)" in
    Darwin) echo "${HOME}/Library/Android/sdk" ;;
    Linux)  echo "${HOME}/Android/Sdk" ;;
    *)      echo "${LOCALAPPDATA:-${HOME}}/Android/Sdk" ;;
  esac
}
SDK_ROOT="$(detect_sdk_root)"

# ── پکیج‌های موردنیاز این پروژه (compileSdk=34, AGP 8.5.2) ──────────────────
# الگوهای جستجو در ستون package_path فایل CSV
NEEDED=(
  "platforms;android-34"
  "build-tools;34.0.0"
  "platform-tools"
  "cmdline-tools;latest"
)

echo "مسیر SDK: ${SDK_ROOT}"
echo "در حال دریافت فهرست پکیج‌ها از مایکت ..."
echo

TMP_CSV="$(mktemp)"
trap 'rm -f "${TMP_CSV}"' EXIT

if ! curl -fsSL --max-time 120 "${CSV_URL}" -o "${TMP_CSV}"; then
  echo "❌ دانلود فایل CSV ناموفق بود."
  echo "   دستی باز کنید: ${CSV_URL}"
  exit 1
fi

echo "✅ فهرست دریافت شد ($(wc -l < "${TMP_CSV}") ردیف)"
echo

# ── پیدا کردن و پردازش هر پکیج ───────────────────────────────────────────────
for pkg in "${NEEDED[@]}"; do
  echo "── ${pkg}"

  # ستون اول = package_path ، ستون چهارم = archive_url
  # لینوکس را ترجیح می‌دهیم؛ اگر نبود اولین نتیجه
  line=$(awk -F',' -v p="${pkg}" '$1 == p' "${TMP_CSV}" | grep -i -m1 "linux" \
       || awk -F',' -v p="${pkg}" '$1 == p' "${TMP_CSV}" | head -1)

  if [[ -z "${line}" ]]; then
    echo "   ⚠️  در CSV پیدا نشد — دستی جستجو کنید: ${CSV_URL}"
    continue
  fi

  url=$(echo "${line}" | awk -F',' '{print $4}' | tr -d '"' | xargs)
  name=$(echo "${line}" | awk -F',' '{print $2}' | tr -d '"' | xargs)

  if [[ -z "${url}" ]]; then
    echo "   ⚠️  لینک استخراج نشد"
    continue
  fi

  echo "   ${name}"
  echo "   ${url}"

  [[ ${LIST_ONLY} -eq 1 ]] && { echo; continue; }

  # مسیر مقصد از روی package_path ساخته می‌شود (';' → '/')
  dest="${SDK_ROOT}/${pkg//;//}"
  if [[ -d "${dest}" ]] && [[ -n "$(ls -A "${dest}" 2>/dev/null)" ]]; then
    echo "   ⏭️  از قبل نصب است"
    echo
    continue
  fi

  zipfile="$(mktemp).zip"
  echo "   ⬇️  در حال دانلود ..."
  if ! curl -fL --max-time 1800 --progress-bar "${url}" -o "${zipfile}"; then
    echo "   ❌ دانلود ناموفق"
    rm -f "${zipfile}"
    echo
    continue
  fi

  mkdir -p "${dest}"
  # آرشیوهای SDK معمولاً یک پوشهٔ ریشه دارند که باید حذف شود
  tmpdir="$(mktemp -d)"
  unzip -q "${zipfile}" -d "${tmpdir}"
  inner_count=$(find "${tmpdir}" -mindepth 1 -maxdepth 1 -type d | wc -l)
  file_count=$(find "${tmpdir}" -mindepth 1 -maxdepth 1 -type f | wc -l)
  if [[ "${inner_count}" -eq 1 && "${file_count}" -eq 0 ]]; then
    inner="$(find "${tmpdir}" -mindepth 1 -maxdepth 1 -type d)"
    cp -r "${inner}/." "${dest}/"
  else
    cp -r "${tmpdir}/." "${dest}/"
  fi
  rm -rf "${tmpdir}" "${zipfile}"
  echo "   ✅ نصب شد در ${dest}"
  echo
done

if [[ ${LIST_ONLY} -eq 0 ]]; then
  echo "─────────────────────────────────────────────"
  echo "حالا فایل local.properties را بسازید:"
  echo "    echo \"sdk.dir=${SDK_ROOT}\" > local.properties"
  echo
  echo "و پذیرش لایسنس‌ها (اگر cmdline-tools نصب شد):"
  echo "    \"${SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager\" --licenses"
fi
