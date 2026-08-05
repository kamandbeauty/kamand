<#
.SYNOPSIS
    نصب Android SDK از میرور مایکت روی ویندوز (بدون نیاز به dl.google.com)

.DESCRIPTION
    پکیج‌های موردنیاز پروژه فاکتوریار را از CSV مایکت پیدا، دانلود و در مسیر
    درست extract می‌کند. سپس فایل‌های لایسنس و local.properties را می‌سازد.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\fetch-android-sdk.ps1
    powershell -ExecutionPolicy Bypass -File scripts\fetch-android-sdk.ps1 -List
    powershell -ExecutionPolicy Bypass -File scripts\fetch-android-sdk.ps1 -Emulator

.NOTES
    مرجع: https://maven.myket.ir/services/android-sdk.html
#>

param(
    [switch]$List,       # فقط نمایش لینک‌ها، بدون دانلود
    [switch]$Emulator,   # امولاتور را هم نصب کن (~400MB)
    [string]$SdkRoot     # مسیر دلخواه SDK
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # سرعت دانلود را بسیار بالا می‌برد

$CsvUrl = 'https://maven.myket.ir/sdk-archives.csv'

# ── تعیین مسیر SDK ───────────────────────────────────────────────────────────
if (-not $SdkRoot) {
    if ($env:ANDROID_SDK_ROOT)  { $SdkRoot = $env:ANDROID_SDK_ROOT }
    elseif ($env:ANDROID_HOME)  { $SdkRoot = $env:ANDROID_HOME }
    else { $SdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
}

Write-Host '─────────────────────────────────────────────'
Write-Host " مسیر SDK : $SdkRoot"
Write-Host '─────────────────────────────────────────────'
Write-Host ''

New-Item -ItemType Directory -Force -Path $SdkRoot | Out-Null

# ── پکیج‌های موردنیاز (compileSdk = 34) ──────────────────────────────────────
$Packages = @('platforms;android-34', 'build-tools;34.0.0', 'platform-tools')
if ($Emulator) { $Packages += 'emulator' }

# ── دریافت CSV ───────────────────────────────────────────────────────────────
Write-Host 'دریافت فهرست پکیج‌ها از مایکت ...'
try {
    $raw = (Invoke-WebRequest -Uri $CsvUrl -UseBasicParsing -TimeoutSec 180).Content
} catch {
    Write-Host "❌ دانلود CSV ناموفق: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   دستی باز کنید: $CsvUrl"
    exit 1
}
$rows = $raw | ConvertFrom-Csv
Write-Host "✅ $($rows.Count) ردیف دریافت شد"
Write-Host ''

# ── انتخاب بهترین ردیف برای هر پکیج ─────────────────────────────────────────
function Select-Row {
    param([string]$PackagePath)

    $matches = $rows | Where-Object { $_.package_path -eq $PackagePath }
    if (-not $matches) { return $null }

    # ترجیح نسخهٔ ویندوز؛ اگر پکیج مستقل از OS بود، همه را نگه دار
    $win = $matches | Where-Object { $_.archive_url -match 'win' }
    if ($win) { $matches = $win }

    # بالاترین revision
    return $matches | Sort-Object {
        try { [version]($_.package_revision -replace '[^0-9.]', '') } catch { [version]'0.0' }
    } -Descending | Select-Object -First 1
}

$failed = $false

foreach ($pkg in $Packages) {
    Write-Host "── $pkg"
    $row = Select-Row -PackagePath $pkg

    if (-not $row) {
        Write-Host '   ⚠️  در CSV یافت نشد' -ForegroundColor Yellow
        $failed = $true
        Write-Host ''
        continue
    }

    $mb = [math]::Round([int64]$row.archive_size / 1MB, 1)
    Write-Host "   $($row.package_display_name)  (~${mb}MB)"
    Write-Host "   $($row.archive_url)" -ForegroundColor DarkGray

    if ($List) { Write-Host ''; continue }

    $dest = Join-Path $SdkRoot ($pkg -replace ';', '\')
    if ((Test-Path $dest) -and (Get-ChildItem $dest -ErrorAction SilentlyContinue)) {
        Write-Host '   ⏭️  از قبل نصب است' -ForegroundColor DarkGray
        Write-Host ''
        continue
    }

    $zip = Join-Path $env:TEMP "sdk_$([guid]::NewGuid().ToString('N')).zip"
    Write-Host '   ⬇️  در حال دانلود ...'
    try {
        Invoke-WebRequest -Uri $row.archive_url -OutFile $zip -UseBasicParsing -TimeoutSec 3600
    } catch {
        Write-Host "   ❌ دانلود ناموفق: $($_.Exception.Message)" -ForegroundColor Red
        Remove-Item $zip -ErrorAction SilentlyContinue
        $failed = $true
        Write-Host ''
        continue
    }

    $tmp = Join-Path $env:TEMP "sdkx_$([guid]::NewGuid().ToString('N'))"
    try {
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
    } catch {
        Write-Host '   ❌ فایل ZIP خراب است' -ForegroundColor Red
        Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
        $failed = $true
        Write-Host ''
        continue
    }

    New-Item -ItemType Directory -Force -Path $dest | Out-Null

    # آرشیوهای SDK معمولاً یک پوشهٔ ریشهٔ اضافه دارند که باید حذف شود
    $dirs  = @(Get-ChildItem $tmp -Directory)
    $files = @(Get-ChildItem $tmp -File)
    if ($dirs.Count -eq 1 -and $files.Count -eq 0) {
        Copy-Item -Path (Join-Path $dirs[0].FullName '*') -Destination $dest -Recurse -Force
    } else {
        Copy-Item -Path (Join-Path $tmp '*') -Destination $dest -Recurse -Force
    }

    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ نصب شد: $dest" -ForegroundColor Green
    Write-Host ''
}

if ($List) { exit 0 }

# ── ساخت فایل‌های لایسنس (هش‌های عمومی و ثابت گوگل) ─────────────────────────
Write-Host '── پذیرش لایسنس‌ها'
$licDir = Join-Path $SdkRoot 'licenses'
New-Item -ItemType Directory -Force -Path $licDir | Out-Null

$licenses = @{
    'android-sdk-license'         = @('8933bad161af4178b1185d1a37fbf41ea5269c55',
                                      'd56f5187479451eabf01fb78af6dfcb131a6481e',
                                      '24333f8a63b6825ea9c5514f83c2829b004d1fee')
    'android-sdk-preview-license' = @('84831b9409646a918e30573bab4c9c91346d8abd',
                                      '504667f4c0de7af1a06de9f4b1727b84351f2910')
    'android-googletv-license'    = @('33b6a2b64607f11b759f320ef9dff4ae5c47d97a')
    'intel-android-extra-license' = @('d975f751698a77b662f1254ddbeed3901e976f5a')
    'android-sdk-arm-dbt-license' = @('33b6a2b64607f11b759f320ef9dff4ae5c47d97a')
}
foreach ($name in $licenses.Keys) {
    $content = "`n" + ($licenses[$name] -join "`n") + "`n"
    [System.IO.File]::WriteAllText((Join-Path $licDir $name), $content)
}
Write-Host "   ✅ $licDir" -ForegroundColor Green
Write-Host ''

# ── ساخت local.properties ────────────────────────────────────────────────────
$projectRoot = Split-Path -Parent $PSScriptRoot
$lp = Join-Path $projectRoot 'local.properties'
if (-not (Test-Path $lp)) {
    # در فرمت properties بک‌اسلش و دونقطه باید escape شوند
    $escaped = $SdkRoot -replace '\\', '\\\\' -replace ':', '\:'
    [System.IO.File]::WriteAllText($lp, "sdk.dir=$escaped`n")
    Write-Host '✅ local.properties ساخته شد' -ForegroundColor Green
} else {
    Write-Host 'ℹ️  local.properties از قبل وجود دارد'
}
Write-Host ''

# ── بررسی نهایی ──────────────────────────────────────────────────────────────
Write-Host '─────────────────────────────────────────────'
Write-Host ' بررسی نصب'
Write-Host '─────────────────────────────────────────────'

$checks = @(
    @{ Path = 'platforms\android-34\android.jar'; Label = 'Platform 34' },
    @{ Path = 'build-tools\34.0.0\aapt2.exe';     Label = 'Build-Tools 34.0.0' },
    @{ Path = 'platform-tools\adb.exe';           Label = 'Platform-Tools' }
)
$ok = $true
foreach ($c in $checks) {
    $full = Join-Path $SdkRoot $c.Path
    if (Test-Path $full) {
        Write-Host "  ✅ $($c.Label)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($c.Label)   ($full)" -ForegroundColor Red
        $ok = $false
    }
}
Write-Host ''

if ($ok -and -not $failed) {
    Write-Host '🎉 آماده است. حالا اجرا کنید:' -ForegroundColor Green
    Write-Host '     .\gradlew.bat :app:assembleDebug'
} else {
    Write-Host '⚠️  بعضی پکیج‌ها نصب نشدند.' -ForegroundColor Yellow
    Write-Host '   راهنمای نصب دستی: docs\ANDROID_SDK_SETUP.md'
    exit 1
}
