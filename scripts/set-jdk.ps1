<#
.SYNOPSIS
    پیدا کردن JDK 17 روی سیستم و تنظیم آن برای Gradle

.DESCRIPTION
    دو خطای رایج را رفع می‌کند:
      • «This build uses a Java 8 JVM»  → جاوا خیلی قدیمی است
      • خطای مبهم با شمارهٔ نسخه مثل «25.0.4» → جاوا خیلی جدید است

    محدودهٔ سازگار برای این پروژه: Java 17 تا 23
      • حداقل 17 → الزام AGP 8.5
      • حداکثر 23 → سقف پشتیبانی Gradle 8.10.2

    این اسکریپت JDKهای نصب‌شده را پیدا می‌کند (به‌ویژه JBR همراه Android Studio
    که همیشه نسخهٔ درست است) و مسیرش را در gradle.properties می‌نویسد.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\set-jdk.ps1
    powershell -ExecutionPolicy Bypass -File scripts\set-jdk.ps1 -JdkPath "C:\Program Files\Java\jdk-17"
#>

param(
    [string]$JdkPath   # مسیر دستی، اگر خودکار پیدا نشد
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '═══════════════════════════════════════════════════'
Write-Host '  تنظیم JDK برای Gradle'
Write-Host '═══════════════════════════════════════════════════'
Write-Host ''

# ── نسخهٔ جاوای فعلی ─────────────────────────────────────────────────────────
Write-Host '── جاوای فعلی در PATH'
try {
    $v = (& java -version 2>&1 | Select-Object -First 1) -join ''
    Write-Host "   $v"
} catch {
    Write-Host '   (java در PATH نیست)' -ForegroundColor DarkGray
}
Write-Host ''

# ── جستجوی JDK ───────────────────────────────────────────────────────────────
function Get-JdkVersion {
    param([string]$Path)
    $exe = Join-Path $Path 'bin\java.exe'
    if (-not (Test-Path $exe)) { return $null }
    try {
        $out = (& $exe -version 2>&1 | Select-Object -First 1) -join ''
        if ($out -match '"(\d+)') { return [int]$Matches[1] }        # "17.0.11"
        if ($out -match '"1\.(\d+)') { return [int]$Matches[1] }     # "1.8.0"
    } catch { }
    return $null
}

$candidates = @()

if ($JdkPath) { $candidates += $JdkPath }

# ۱) JetBrains Runtime همراه Android Studio — بهترین گزینه
$candidates += @(
    "${env:ProgramFiles}\Android\Android Studio\jbr",
    "${env:ProgramFiles}\Android\Android Studio\jre",
    "${env:LOCALAPPDATA}\Programs\Android Studio\jbr",
    "${env:ProgramFiles(x86)}\Android\Android Studio\jbr"
)

# ۲) متغیرهای محیطی
if ($env:JAVA_HOME)   { $candidates += $env:JAVA_HOME }
if ($env:JDK_HOME)    { $candidates += $env:JDK_HOME }
if ($env:STUDIO_JDK)  { $candidates += $env:STUDIO_JDK }

# ۳) مسیرهای رایج نصب
foreach ($root in @("${env:ProgramFiles}\Java", "${env:ProgramFiles}\Eclipse Adoptium",
                    "${env:ProgramFiles}\Microsoft", "${env:ProgramFiles}\Amazon Corretto",
                    "${env:ProgramFiles}\BellSoft", "${env:ProgramFiles}\Zulu")) {
    if (Test-Path $root) {
        $candidates += (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
                        Select-Object -ExpandProperty FullName)
    }
}

Write-Host '── JDKهای پیداشده'
$found = @()
foreach ($c in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
    $ver = Get-JdkVersion -Path $c
    if ($ver) {
        $mark = if ($ver -ge 17 -and $ver -le 23) { '✅' }
                elseif ($ver -gt 23) { '🚫' }
                else { '❌' }
        Write-Host "   $mark Java $ver  —  $c"
        $found += [pscustomobject]@{ Version = $ver; Path = $c }
    }
}

if ($found.Count -eq 0) {
    Write-Host '   هیچ JDK پیدا نشد!' -ForegroundColor Red
    Write-Host ''
    Write-Host 'راه‌حل: Android Studio معمولاً JDK داخلی دارد. اگر نصب است،'
    Write-Host 'مسیرش را دستی بدهید:'
    Write-Host '   .\scripts\set-jdk.ps1 -JdkPath "C:\Program Files\Android\Android Studio\jbr"'
    exit 1
}
Write-Host ''

# ── انتخاب نسخهٔ سازگار ──────────────────────────────────────────────────────
#  محدودهٔ مجاز: Java 17 تا 23
#    • حداقل ۱۷ → الزام AGP 8.5
#    • حداکثر ۲۳ → سقف پشتیبانی Gradle 8.10.2
#      (Java 24 نیازمند Gradle 8.14 و Java 25 نیازمند Gradle 9.1 است)
#  ترتیب ترجیح: 17 (LTS و پیش‌فرض Android Studio) → 21 → 20 → 19 → 18 → 23 → 22
$preference = @(17, 21, 20, 19, 18, 23, 22)

$best = $null
foreach ($v in $preference) {
    $match = $found | Where-Object { $_.Version -eq $v } | Select-Object -First 1
    if ($match) { $best = $match; break }
}

if (-not $best) {
    Write-Host '❌ هیچ JDK سازگاری پیدا نشد.' -ForegroundColor Red
    Write-Host ''
    Write-Host '   این پروژه به Java 17 تا 23 نیاز دارد:'
    Write-Host '     • حداقل 17 — الزام Android Gradle Plugin 8.5'
    Write-Host '     • حداکثر 23 — سقف پشتیبانی Gradle 8.10.2'
    Write-Host ''
    $tooNew = $found | Where-Object { $_.Version -gt 23 }
    if ($tooNew) {
        Write-Host "   ⚠️  Java $($tooNew[0].Version) روی سیستم دارید که برای این Gradle خیلی جدید است." -ForegroundColor Yellow
        Write-Host ''
    }
    Write-Host '   راه‌حل‌ها:'
    Write-Host '     ۱) اگر Android Studio نصب است، معمولاً JDK 17 داخلی دارد:'
    Write-Host '        .\scripts\set-jdk.ps1 -JdkPath "C:\Program Files\Android\Android Studio\jbr"'
    Write-Host '     ۲) Temurin 17 را نصب کنید: https://adoptium.net'
    exit 1
}

Write-Host "── انتخاب‌شده: Java $($best.Version)" -ForegroundColor Green
Write-Host "   $($best.Path)"
Write-Host ''

# ── نوشتن در gradle.properties ───────────────────────────────────────────────
$projectRoot = Split-Path -Parent $PSScriptRoot
$gp = Join-Path $projectRoot 'gradle.properties'

# در فرمت properties بک‌اسلش و دونقطه باید escape شوند
$escaped = $best.Path -replace '\\', '\\\\' -replace ':', '\:'
$line = "org.gradle.java.home=$escaped"

if (Test-Path $gp) {
    $lines = @(Get-Content $gp -Encoding UTF8)
} else {
    $lines = @()
}

if ($lines -match '^\s*org\.gradle\.java\.home\s*=') {
    # خط موجود را جایگزین کن
    $lines = $lines | ForEach-Object {
        if ($_ -match '^\s*org\.gradle\.java\.home\s*=') { $line } else { $_ }
    }
    Write-Host '✅ org.gradle.java.home به‌روزرسانی شد' -ForegroundColor Green
} else {
    $lines += ''
    $lines += '# مسیر JDK برای Gradle (AGP 8.5 حداقل Java 17 لازم دارد)'
    $lines += $line
    Write-Host '✅ org.gradle.java.home اضافه شد' -ForegroundColor Green
}
$lines | Set-Content $gp -Encoding UTF8
Write-Host "   $line"
Write-Host ''

if ($best.Version -ne 17) {
    Write-Host "ℹ️  Java $($best.Version) انتخاب شد (سازگار است)." -ForegroundColor Cyan
    Write-Host '   اگر خطای عجیبی دیدید، Java 17 مطمئن‌ترین گزینه است.'
    Write-Host ''
}

Write-Host '═══════════════════════════════════════════════════'
Write-Host ' حالا اجرا کنید:' -ForegroundColor Cyan
Write-Host '   .\gradlew.bat --stop'
Write-Host '   .\gradlew.bat :app:assembleDebug'
Write-Host '═══════════════════════════════════════════════════'
