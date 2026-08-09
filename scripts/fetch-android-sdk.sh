#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  نصب Android SDK از میرور مایکت (بدون نیاز به dl.google.com)
#
#  استفاده:
#      bash scripts/fetch-android-sdk.sh            # پکیج‌های ضروری
#      bash scripts/fetch-android-sdk.sh --list     # فقط نمایش لینک‌ها
#      bash scripts/fetch-android-sdk.sh --emulator # + امولاتور (۴۰۰MB)
#
#  مرجع: https://maven.myket.ir/services/android-sdk.html
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

CSV_URL="https://maven.myket.ir/sdk-archives.csv"
LIST_ONLY=0
WITH_EMULATOR=0
for arg in "$@"; do
  case "${arg}" in
    --list)     LIST_ONLY=1 ;;
    --emulator) WITH_EMULATOR=1 ;;
  esac
done

# ── تشخیص سیستم‌عامل (برای انتخاب آرشیو درست) ───────────────────────────────
case "$(uname -s)" in
  Darwin)           OS_TAG="darwin"; SDK_DEFAULT="${HOME}/Library/Android/sdk" ;;
  Linux)            OS_TAG="linux";  SDK_DEFAULT="${HOME}/Android/Sdk" ;;
  MINGW*|MSYS*|CYGWIN*) OS_TAG="win"; SDK_DEFAULT="${LOCALAPPDATA:-${HOME}}/Android/Sdk" ;;
  *)                OS_TAG="linux";  SDK_DEFAULT="${HOME}/Android/Sdk" ;;
esac
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-${SDK_DEFAULT}}}"

echo "─────────────────────────────────────────────"
echo " سیستم‌عامل : ${OS_TAG}"
echo " مسیر SDK   : ${SDK_ROOT}"
echo "─────────────────────────────────────────────"
echo

# ── پکیج‌های موردنیاز پروژه (compileSdk=34) ─────────────────────────────────
PKGS=( "platforms;android-34" "build-tools;34.0.0" "platform-tools" )
[[ ${WITH_EMULATOR} -eq 1 ]] && PKGS+=( "emulator" )

TMP_CSV="$(mktemp)"; trap 'rm -f "${TMP_CSV}"' EXIT
echo "دریافت فهرست پکیج‌ها از مایکت ..."
if ! curl -fsSL --max-time 180 "${CSV_URL}" -o "${TMP_CSV}"; then
  echo "❌ دانلود CSV ناموفق. دستی باز کنید: ${CSV_URL}"
  exit 1
fi
echo "✅ $(wc -l < "${TMP_CSV}") ردیف دریافت شد"
echo

# انتخاب بهترین ردیف: تطابق دقیق package_path + سازگاری با OS + بالاترین revision
pick_row() {
  local pkg="$1"
  local rows
  rows=$(awk -F',' -v p="${pkg}" '$1 == p' "${TMP_CSV}")
  [[ -z "${rows}" ]] && return 1

  local os_rows
  case "${OS_TAG}" in
    linux)  os_rows=$(echo "${rows}" | grep -iE 'linux' || true) ;;
    darwin) os_rows=$(echo "${rows}" | grep -iE 'darwin|macosx' || true) ;;
    win)    os_rows=$(echo "${rows}" | grep -iE 'win' || true) ;;
  esac
  # پکیج‌های مستقل از سیستم‌عامل (مثل platforms) فیلتر OS ندارند
  [[ -z "${os_rows}" ]] && os_rows="${rows}"
  # بالاترین revision (ستون ۳) را بردار
  echo "${os_rows}" | sort -t',' -k3 -Vr | head -1
}

FAILED=0
for pkg in "${PKGS[@]}"; do
  echo "── ${pkg}"
  row="$(pick_row "${pkg}")" || { echo "   ⚠️  در CSV یافت نشد"; FAILED=1; echo; continue; }

  name=$(echo "${row}" | awk -F',' '{print $2}')
  url=$(echo  "${row}" | awk -F',' '{print $4}')
  size=$(echo "${row}" | awk -F',' '{print $5}')
  mb=$(( ${size:-0} / 1048576 ))

  echo "   ${name}  (~${mb}MB)"
  echo "   ${url}"

  if [[ ${LIST_ONLY} -eq 1 ]]; then echo; continue; fi

  dest="${SDK_ROOT}/${pkg//;//}"
  if [[ -d "${dest}" && -n "$(ls -A "${dest}" 2>/dev/null)" ]]; then
    echo "   ⏭️  از قبل نصب است"; echo; continue
  fi

  zipf="$(mktemp).zip"
  echo "   ⬇️  دانلود ..."
  if ! curl -fL --max-time 3600 --progress-bar "${url}" -o "${zipf}"; then
    echo "   ❌ دانلود ناموفق"; rm -f "${zipf}"; FAILED=1; echo; continue
  fi

  tmpd="$(mktemp -d)"
  if ! unzip -q "${zipf}" -d "${tmpd}"; then
    echo "   ❌ فایل ZIP خراب است"; rm -rf "${tmpd}" "${zipf}"; FAILED=1; echo; continue
  fi

  mkdir -p "${dest}"
  # آرشیوهای SDK معمولاً یک پوشهٔ ریشهٔ اضافه دارند که باید حذف شود
  ndir=$(find "${tmpd}" -mindepth 1 -maxdepth 1 -type d | wc -l)
  nfile=$(find "${tmpd}" -mindepth 1 -maxdepth 1 -type f | wc -l)
  if [[ "${ndir}" -eq 1 && "${nfile}" -eq 0 ]]; then
    cp -r "$(find "${tmpd}" -mindepth 1 -maxdepth 1 -type d)/." "${dest}/"
  else
    cp -r "${tmpd}/." "${dest}/"
  fi
  rm -rf "${tmpd}" "${zipf}"
  echo "   ✅ نصب شد: ${dest}"
  echo
done

[[ ${LIST_ONLY} -eq 1 ]] && exit 0

# ── ساخت فایل‌های لایسنس (هش‌های عمومی و ثابت گوگل) ─────────────────────────
echo "── پذیرش لایسنس‌ها"
LIC="${SDK_ROOT}/licenses"; mkdir -p "${LIC}"
printf '\n8933bad161af4178b1185d1a37fbf41ea5269c55\nd56f5187479451eabf01fb78af6dfcb131a6481e\n24333f8a63b6825ea9c5514f83c2829b004d1fee\n' > "${LIC}/android-sdk-license"
printf '\n84831b9409646a918e30573bab4c9c91346d8abd\n504667f4c0de7af1a06de9f4b1727b84351f2910\n' > "${LIC}/android-sdk-preview-license"
printf '\n33b6a2b64607f11b759f320ef9dff4ae5c47d97a\n' > "${LIC}/android-googletv-license"
printf '\nd975f751698a77b662f1254ddbeed3901e976f5a\n' > "${LIC}/intel-android-extra-license"
printf '\n33b6a2b64607f11b759f320ef9dff4ae5c47d97a\n' > "${LIC}/android-sdk-arm-dbt-license"
echo "   ✅ ${LIC}"
echo

# ── ساخت local.properties ────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LP="${ROOT}/local.properties"
if [[ ! -f "${LP}" ]]; then
  if [[ "${OS_TAG}" == "win" ]]; then
    echo "sdk.dir=$(echo "${SDK_ROOT}" | sed 's|/|\\\\|g; s|^\([A-Za-z]\):|\1\\:|')" > "${LP}"
  else
    echo "sdk.dir=${SDK_ROOT}" > "${LP}"
  fi
  echo "✅ local.properties ساخته شد"
else
  echo "ℹ️  local.properties از قبل وجود دارد"
fi
echo

# ── بررسی نهایی ──────────────────────────────────────────────────────────────
echo "─────────────────────────────────────────────"
echo " بررسی نصب"
echo "─────────────────────────────────────────────"
ok=1
for check in \
  "platforms/android-34/android.jar:Platform 34" \
  "build-tools/34.0.0:Build-Tools" \
  "platform-tools:Platform-Tools"
do
  path="${check%%:*}"; label="${check##*:}"
  if [[ -e "${SDK_ROOT}/${path}" ]]; then
    echo "  ✅ ${label}"
  else
    echo "  ❌ ${label}  (${SDK_ROOT}/${path})"
    ok=0
  fi
done
echo

if [[ ${ok} -eq 1 && ${FAILED} -eq 0 ]]; then
  echo "🎉 آماده است. حالا اجرا کنید:"
  echo "     ./gradlew :app:assembleDebug"
else
  echo "⚠️  بعضی پکیج‌ها نصب نشدند."
  echo "   راهنمای نصب دستی: docs/ANDROID_SDK_SETUP.md"
  exit 1
fi
