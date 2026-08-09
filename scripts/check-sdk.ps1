<#
.SYNOPSIS
    عیب‌یابی خطای «Failed to find target with hash string 'android-34'»

.DESCRIPTION
    ساختار پوشهٔ SDK را بررسی می‌کند و مشکلات رایج (پوشهٔ تودرتو، فایل ناقص،
    source.properties غلط) را پیدا و در صورت امکان اصلاح می‌کند.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\check-sdk.ps1
    powershell -ExecutionPolicy Bypass -File scripts\check-sdk.ps1 -Fix
#>

param(
    [switch]$Fix,
    [string]$SdkRoot
)

$ErrorActionPreference = 'Continue'

if (-not $SdkRoot) {
    if ($env:ANDROID_SDK_ROOT)  { $SdkRoot = $env:ANDROID_SDK_ROOT }
    elseif ($env:ANDROID_HOME)  { $SdkRoot = $env:ANDROID_HOME }
    else { $SdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
}

Write-Host '═════════════════════════════════════════════'
Write-Host " بررسی Android SDK"
Write-Host " مسیر: $SdkRoot"
Write-Host '═════════════════════════════════════════════'
Write-Host ''

if (-not (Test-Path $SdkRoot)) {
    Write-Host "❌ مسیر SDK وجود ندارد!" -ForegroundColor Red
    Write-Host "   ابتدا اجرا کنید: scripts\fetch-android-sdk.ps1"
    exit 1
}

$problems = 0

# ── ۱) Platform 34 ───────────────────────────────────────────────────────────
Write-Host '── ۱. Android Platform 34'
$plat = Join-Path $SdkRoot 'platforms\android-34'

if (-not (Test-Path $plat)) {
    Write-Host '   ❌ پوشه platforms\android-34 وجود ندارد' -ForegroundColor Red
    # شاید با نام دیگری extract شده باشد
    $platsDir = Join-Path $SdkRoot 'platforms'
    if (Test-Path $platsDir) {
        $others = Get-ChildItem $platsDir -Directory -ErrorAction SilentlyContinue
        if ($others) {
            Write-Host '   پوشه‌های موجود در platforms:' -ForegroundColor Yellow
            $others | ForEach-Object { Write-Host "     - $($_.Name)" }
            Write-Host '   💡 اگر یکی از این‌ها API 34 است، نامش را به android-34 تغییر دهید.'
        }
    }
    $problems++
} else {
    $jar = Join-Path $plat 'android.jar'

    # حالت رایج: پوشهٔ تودرتو (platforms\android-34\android-14\android.jar)
    if (-not (Test-Path $jar)) {
        $nested = Get-ChildItem $plat -Directory -ErrorAction SilentlyContinue |
                  Where-Object { Test-Path (Join-Path $_.FullName 'android.jar') } |
                  Select-Object -First 1
        if ($nested) {
            Write-Host "   ⚠️  پوشهٔ تودرتو پیدا شد: $($nested.Name)" -ForegroundColor Yellow
            if ($Fix) {
                Write-Host '   🔧 در حال اصلاح ...'
                Copy-Item -Path (Join-Path $nested.FullName '*') -Destination $plat -Recurse -Force
                Remove-Item $nested.FullName -Recurse -Force
                Write-Host '   ✅ اصلاح شد' -ForegroundColor Green
            } else {
                Write-Host '   💡 برای اصلاح خودکار، با سوییچ -Fix اجرا کنید'
                $problems++
            }
        } else {
            Write-Host '   ❌ android.jar پیدا نشد — آرشیو ناقص است' -ForegroundColor Red
            Write-Host '   💡 پوشه را پاک و دوباره دانلود کنید'
            $problems++
        }
    }

    if (Test-Path $jar) {
        $size = [math]::Round((Get-Item $jar).Length / 1MB, 1)
        Write-Host "   ✅ android.jar موجود (${size}MB)" -ForegroundColor Green
        if ($size -lt 5) {
            Write-Host '   ⚠️  حجم غیرعادی کم — احتمالاً دانلود ناقص بوده' -ForegroundColor Yellow
            $problems++
        }
    }

    # source.properties باید ApiLevel=34 داشته باشد
    $sp = Join-Path $plat 'source.properties'
    if (Test-Path $sp) {
        $api = (Get-Content $sp | Where-Object { $_ -match 'AndroidVersion\.ApiLevel' })
        if ($api) {
            Write-Host "   ✅ $($api.Trim())" -ForegroundColor Green
            if ($api -notmatch '=\s*34') {
                Write-Host '   ❌ سطح API با 34 نمی‌خواند!' -ForegroundColor Red
                $problems++
            }
        }
    } else {
        Write-Host '   ⚠️  source.properties نیست — AGP نمی‌تواند پلتفرم را بشناسد' -ForegroundColor Yellow
        if ($Fix) {
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
            Write-Host '   ✅ source.properties ساخته شد' -ForegroundColor Green
        } else {
            Write-Host '   💡 با -Fix اجرا کنید تا ساخته شود'
            $problems++
        }
    }
}
Write-Host ''

# ── ۲) Build-Tools ───────────────────────────────────────────────────────────
Write-Host '── ۲. Build-Tools'
$bt = Join-Path $SdkRoot 'build-tools'
if (-not (Test-Path $bt)) {
    Write-Host '   ❌ پوشه build-tools وجود ندارد' -ForegroundColor Red
    $problems++
} else {
    $vers = Get-ChildItem $bt -Directory -ErrorAction SilentlyContinue
    if (-not $vers) {
        Write-Host '   ❌ هیچ نسخه‌ای نصب نیست' -ForegroundColor Red
        $problems++
    } else {
        foreach ($v in $vers) {
            $aapt = Join-Path $v.FullName 'aapt2.exe'
            if (Test-Path $aapt) {
                Write-Host "   ✅ $($v.Name)" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  $($v.Name) — aapt2.exe ندارد (ناقص)" -ForegroundColor Yellow
                $nested = Get-ChildItem $v.FullName -Directory -ErrorAction SilentlyContinue |
                          Where-Object { Test-Path (Join-Path $_.FullName 'aapt2.exe') } |
                          Select-Object -First 1
                if ($nested -and $Fix) {
                    Copy-Item -Path (Join-Path $nested.FullName '*') -Destination $v.FullName -Recurse -Force
                    Remove-Item $nested.FullName -Recurse -Force
                    Write-Host '   ✅ پوشهٔ تودرتو اصلاح شد' -ForegroundColor Green
                } else {
                    $problems++
                }
            }
        }
    }
}
Write-Host ''

# ── ۳) Platform-Tools ────────────────────────────────────────────────────────
Write-Host '── ۳. Platform-Tools'
$adb = Join-Path $SdkRoot 'platform-tools\adb.exe'
if (Test-Path $adb) {
    Write-Host '   ✅ adb.exe موجود' -ForegroundColor Green
} else {
    Write-Host '   ⚠️  adb.exe نیست (برای نصب روی گوشی لازم است)' -ForegroundColor Yellow
}
Write-Host ''

# ── ۴) لایسنس‌ها ─────────────────────────────────────────────────────────────
Write-Host '── ۴. لایسنس‌ها'
$lic = Join-Path $SdkRoot 'licenses\android-sdk-license'
if (Test-Path $lic) {
    Write-Host '   ✅ پذیرفته شده' -ForegroundColor Green
} else {
    Write-Host '   ❌ پذیرفته نشده' -ForegroundColor Red
    if ($Fix) {
        $licDir = Join-Path $SdkRoot 'licenses'
        New-Item -ItemType Directory -Force -Path $licDir | Out-Null
        [System.IO.File]::WriteAllText($lic,
            "`n8933bad161af4178b1185d1a37fbf41ea5269c55`nd56f5187479451eabf01fb78af6dfcb131a6481e`n24333f8a63b6825ea9c5514f83c2829b004d1fee`n")
        Write-Host '   ✅ ساخته شد' -ForegroundColor Green
    } else {
        $problems++
    }
}
Write-Host ''

# ── ۵) local.properties ──────────────────────────────────────────────────────
Write-Host '── ۵. local.properties'
$projectRoot = Split-Path -Parent $PSScriptRoot
$lp = Join-Path $projectRoot 'local.properties'
if (Test-Path $lp) {
    Write-Host "   ✅ $((Get-Content $lp | Select-Object -First 1))" -ForegroundColor Green
} else {
    Write-Host '   ❌ وجود ندارد' -ForegroundColor Red
    if ($Fix) {
        $escaped = $SdkRoot -replace '\\', '\\\\' -replace ':', '\:'
        [System.IO.File]::WriteAllText($lp, "sdk.dir=$escaped`n")
        Write-Host '   ✅ ساخته شد' -ForegroundColor Green
    } else {
        $problems++
    }
}
Write-Host ''

# ── نتیجه ────────────────────────────────────────────────────────────────────
Write-Host '═════════════════════════════════════════════'
if ($problems -eq 0) {
    Write-Host ' 🎉 همه‌چیز درست است!' -ForegroundColor Green
    Write-Host ''
    Write-Host ' حالا اجرا کنید:'
    Write-Host '   .\gradlew.bat --stop'
    Write-Host '   .\gradlew.bat :app:assembleDebug'
} else {
    Write-Host " ⚠️  $problems مشکل پیدا شد" -ForegroundColor Yellow
    Write-Host ''
    Write-Host ' برای اصلاح خودکار:'
    Write-Host '   powershell -ExecutionPolicy Bypass -File scripts\check-sdk.ps1 -Fix'
}
Write-Host '═════════════════════════════════════════════'
