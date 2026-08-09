<#
.SYNOPSIS
    نصب کامل Android SDK روی ویندوز از میرور مایکت — با لینک‌های ثابت و تأییدشده

.DESCRIPTION
    این اسکریپت CSV را پارس نمی‌کند؛ لینک‌ها از قبل استخراج و بررسی شده‌اند.
    ساختار پوشه‌ها را دقیقاً همان‌طور که AGP انتظار دارد می‌سازد و مشکل رایج
    «پوشهٔ تودرتو» را خودش رفع می‌کند.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\setup-sdk-windows.ps1
    powershell -ExecutionPolicy Bypass -File scripts\setup-sdk-windows.ps1 -Force
    powershell -ExecutionPolicy Bypass -File scripts\setup-sdk-windows.ps1 -Emulator
#>

param(
    [switch]$Force,      # حتی اگر نصب است، دوباره نصب کن
    [switch]$Emulator,   # امولاتور را هم نصب کن (~۴۲۹MB)
    [string]$SdkRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# ── مسیر SDK ─────────────────────────────────────────────────────────────────
if (-not $SdkRoot) {
    if ($env:ANDROID_SDK_ROOT) { $SdkRoot = $env:ANDROID_SDK_ROOT }
    elseif ($env:ANDROID_HOME) { $SdkRoot = $env:ANDROID_HOME }
    else { $SdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
}

Write-Host ''
Write-Host '═══════════════════════════════════════════════════'
Write-Host '  نصب Android SDK از میرور مایکت'
Write-Host "  مسیر: $SdkRoot"
Write-Host '═══════════════════════════════════════════════════'
Write-Host ''

New-Item -ItemType Directory -Force -Path $SdkRoot | Out-Null

# ── لینک‌های تأییدشده (نسخهٔ ویندوز) ─────────────────────────────────────────
$Packages = @(
    @{
        Name     = 'Android Platform 34'
        Dest     = 'platforms\android-34'
        Url      = 'https://maven.myket.ir/android-sdk/platform-34-ext7_r03.zip'
        SizeMB   = 60
        Verify   = 'android.jar'
    },
    @{
        Name     = 'Build-Tools 34.0.0'
        Dest     = 'build-tools\34.0.0'
        Url      = 'https://maven.myket.ir/android-sdk/build-tools_r34-windows.zip'
        SizeMB   = 56
        Verify   = 'aapt2.exe'
    },
    @{
        Name     = 'Platform-Tools (adb)'
        Dest     = 'platform-tools'
        Url      = 'https://maven.myket.ir/android-sdk/platform-tools_r37.0.0-win.zip'
        SizeMB   = 8
        Verify   = 'adb.exe'
    },
    @{
        Name     = 'Command-line Tools'
        Dest     = 'cmdline-tools\latest'
        Url      = 'https://maven.myket.ir/android-sdk/commandlinetools-win-11479570_latest.zip'
        SizeMB   = 130
        Verify   = 'bin\sdkmanager.bat'
    }
)

if ($Emulator) {
    $Packages += @{
        Name   = 'Android Emulator'
        Dest   = 'emulator'
        Url    = 'https://maven.myket.ir/android-sdk/emulator-windows_x64-15142779.zip'
        SizeMB = 409
        Verify = 'emulator.exe'
    }
}

# ── تابع نصب یک پکیج ─────────────────────────────────────────────────────────
function Install-Package {
    param($Pkg)

    $dest     = Join-Path $SdkRoot $Pkg.Dest
    $verifyAt = Join-Path $dest $Pkg.Verify

    Write-Host "── $($Pkg.Name)  (~$($Pkg.SizeMB)MB)"

    if ((Test-Path $verifyAt) -and (-not $Force)) {
        Write-Host '   ⏭️  از قبل نصب و سالم است' -ForegroundColor DarkGray
        Write-Host ''
        return $true
    }

    # پاک‌سازی نصب ناقص قبلی
    if (Test-Path $dest) {
        Write-Host '   🧹 پاک‌سازی نصب ناقص قبلی ...'
        Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
    }

    $zip = Join-Path $env:TEMP "sdk_$([guid]::NewGuid().ToString('N')).zip"
    $tmp = Join-Path $env:TEMP "sdkx_$([guid]::NewGuid().ToString('N'))"

    try {
        Write-Host '   ⬇️  دانلود ...' -NoNewline
        Invoke-WebRequest -Uri $Pkg.Url -OutFile $zip -UseBasicParsing -TimeoutSec 3600
        $actualMB = [math]::Round((Get-Item $zip).Length / 1MB, 1)
        Write-Host " ${actualMB}MB ✓"

        if ($actualMB -lt ($Pkg.SizeMB * 0.5)) {
            Write-Host "   ❌ حجم فایل خیلی کمتر از انتظار است — دانلود ناقص" -ForegroundColor Red
            return $false
        }

        Write-Host '   📦 استخراج ...' -NoNewline
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        Write-Host ' ✓'

        # ── نکتهٔ کلیدی: رفع پوشهٔ تودرتو ────────────────────────────────────
        # آرشیوهای SDK یک پوشهٔ ریشه دارند (مثلاً android-14 یا platform-tools)
        # که باید حذف شود تا ساختار مورد انتظار AGP ساخته شود.
        $source = $tmp
        $dirs   = @(Get-ChildItem $tmp -Directory)
        $files  = @(Get-ChildItem $tmp -File)

        if ($dirs.Count -eq 1 -and $files.Count -eq 0) {
            $source = $dirs[0].FullName
            Write-Host "   📁 پوشهٔ تودرتو '$($dirs[0].Name)' حذف شد"
        }

        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item -Path (Join-Path $source '*') -Destination $dest -Recurse -Force

        # ── بررسی صحت ────────────────────────────────────────────────────────
        if (Test-Path $verifyAt) {
            Write-Host "   ✅ نصب شد: $dest" -ForegroundColor Green
            Write-Host ''
            return $true
        } else {
            Write-Host "   ❌ فایل کلیدی '$($Pkg.Verify)' پیدا نشد" -ForegroundColor Red
            Write-Host '   محتویات:' -ForegroundColor Yellow
            Get-ChildItem $dest | Select-Object -First 8 |
                ForEach-Object { Write-Host "     - $($_.Name)" }
            Write-Host ''
            return $false
        }
    }
    catch {
        Write-Host ''
        Write-Host "   ❌ خطا: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ''
        return $false
    }
    finally {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ── اجرا ─────────────────────────────────────────────────────────────────────
$allOk = $true
foreach ($p in $Packages) {
    if (-not (Install-Package -Pkg $p)) { $allOk = $false }
}

# ── source.properties برای پلتفرم (بدون آن AGP پلتفرم را نمی‌شناسد) ─────────
Write-Host '── source.properties'
$sp = Join-Path $SdkRoot 'platforms\android-34\source.properties'
if (-not (Test-Path $sp)) {
    if (Test-Path (Join-Path $SdkRoot 'platforms\android-34')) {
        @'
Pkg.Desc=Android SDK Platform 34
Pkg.UserSrc=false
Platform.Version=14
Platform.CodeName=
Pkg.Revision=3
AndroidVersion.ApiLevel=34
AndroidVersion.ExtensionLevel=7
AndroidVersion.IsBaseSdk=true
Layoutlib.Api=15
Layoutlib.Revision=1
Platform.MinToolsRev=22
'@ | Set-Content -Path $sp -Encoding ASCII
        Write-Host '   ✅ ساخته شد' -ForegroundColor Green
    }
} else {
    Write-Host '   ✅ موجود است' -ForegroundColor Green
}
Write-Host ''

# ── لایسنس‌ها ────────────────────────────────────────────────────────────────
Write-Host '── لایسنس‌ها'
$licDir = Join-Path $SdkRoot 'licenses'
New-Item -ItemType Directory -Force -Path $licDir | Out-Null
$licenses = @{
    'android-sdk-license'         = "`n8933bad161af4178b1185d1a37fbf41ea5269c55`nd56f5187479451eabf01fb78af6dfcb131a6481e`n24333f8a63b6825ea9c5514f83c2829b004d1fee`n"
    'android-sdk-preview-license' = "`n84831b9409646a918e30573bab4c9c91346d8abd`n504667f4c0de7af1a06de9f4b1727b84351f2910`n"
    'android-googletv-license'    = "`n33b6a2b64607f11b759f320ef9dff4ae5c47d97a`n"
    'intel-android-extra-license' = "`nd975f751698a77b662f1254ddbeed3901e976f5a`n"
    'android-sdk-arm-dbt-license' = "`n33b6a2b64607f11b759f320ef9dff4ae5c47d97a`n"
}
foreach ($k in $licenses.Keys) {
    [System.IO.File]::WriteAllText((Join-Path $licDir $k), $licenses[$k])
}
Write-Host '   ✅ پذیرفته شد' -ForegroundColor Green
Write-Host ''

# ── local.properties ─────────────────────────────────────────────────────────
Write-Host '── local.properties'
$projectRoot = Split-Path -Parent $PSScriptRoot
$lp = Join-Path $projectRoot 'local.properties'
$escaped = $SdkRoot -replace '\\', '\\\\' -replace ':', '\:'
[System.IO.File]::WriteAllText($lp, "sdk.dir=$escaped`n")
Write-Host "   ✅ sdk.dir=$escaped" -ForegroundColor Green
Write-Host ''

# ── بررسی نهایی ──────────────────────────────────────────────────────────────
Write-Host '═══════════════════════════════════════════════════'
Write-Host '  بررسی نهایی'
Write-Host '═══════════════════════════════════════════════════'

$checks = @(
    @{ P = 'platforms\android-34\android.jar';       L = 'Platform 34 (android.jar)' },
    @{ P = 'platforms\android-34\source.properties'; L = 'Platform 34 (metadata)' },
    @{ P = 'build-tools\34.0.0\aapt2.exe';           L = 'Build-Tools 34.0.0' },
    @{ P = 'platform-tools\adb.exe';                 L = 'Platform-Tools' },
    @{ P = 'licenses\android-sdk-license';           L = 'لایسنس' }
)

$fail = 0
foreach ($c in $checks) {
    $full = Join-Path $SdkRoot $c.P
    if (Test-Path $full) {
        Write-Host "  ✅ $($c.L)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($c.L)" -ForegroundColor Red
        Write-Host "     انتظار در: $full" -ForegroundColor DarkGray
        $fail++
    }
}

Write-Host ''
if ($fail -eq 0 -and $allOk) {
    Write-Host '🎉 نصب کامل شد!' -ForegroundColor Green
    Write-Host ''
    Write-Host 'حالا این دو دستور را به ترتیب اجرا کنید:' -ForegroundColor Cyan
    Write-Host '   .\gradlew.bat --stop'
    Write-Host '   .\gradlew.bat :app:assembleDebug'
    Write-Host ''
    Write-Host '⚠️  دستور --stop حتماً لازم است — Gradle نتیجهٔ قبلی را کش کرده.' -ForegroundColor Yellow
} else {
    Write-Host "⚠️  $fail مورد ناقص است." -ForegroundColor Yellow
    Write-Host '   دوباره با -Force اجرا کنید یا راهنمای دستی را ببینید:'
    Write-Host '   docs\ANDROID_SDK_SETUP.md'
    exit 1
}
