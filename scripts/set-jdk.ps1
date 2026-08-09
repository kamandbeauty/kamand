<#
.SYNOPSIS
    پیدا کردن JDK 17 روی سیستم و تنظیم آن برای Gradle

.DESCRIPTION
    خطای «Dependency requires at least JVM runtime version 11. This build uses
    a Java 8 JVM» یعنی Gradle با جاوای قدیمی اجرا می‌شود.

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
        $mark = if ($ver -ge 17) { '✅' } elseif ($ver -ge 11) { '⚠️ ' } else { '❌' }
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

# بهترین گزینه: ترجیحاً ۱۷، وگرنه بالاترین ≥۱۱
$best = $found | Where-Object { $_.Version -eq 17 } | Select-Object -First 1
if (-not $best) { $best = $found | Where-Object { $_.Version -ge 11 } | Sort-Object Version | Select-Object -First 1 }

if (-not $best) {
    Write-Host '❌ هیچ JDK نسخه ۱۱ یا بالاتر پیدا نشد.' -ForegroundColor Red
    Write-Host '   AGP 8.5 حداقل به Java 17 نیاز دارد.'
    Write-Host ''
    Write-Host '   ساده‌ترین راه: Android Studio را نصب کنید (JDK داخلی دارد)'
    Write-Host '   یا Temurin 17 را از adoptium.net بگیرید.'
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

if ($best.Version -lt 17) {
    Write-Host "⚠️  Java $($best.Version) پیدا شد ولی AGP 8.5 رسماً Java 17 می‌خواهد." -ForegroundColor Yellow
    Write-Host '   ممکن است در مراحل بعدی خطا بگیرید.'
    Write-Host ''
}

Write-Host '═══════════════════════════════════════════════════'
Write-Host ' حالا اجرا کنید:' -ForegroundColor Cyan
Write-Host '   .\gradlew.bat --stop'
Write-Host '   .\gradlew.bat :app:assembleDebug'
Write-Host '═══════════════════════════════════════════════════'
