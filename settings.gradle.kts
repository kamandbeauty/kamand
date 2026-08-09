// ─────────────────────────────────────────────────────────────────────────────
//  پیکربندی مخازن — سازگار با هر دو محیط:
//
//  • روی GitHub Actions (متغیر CI ست شده): مخازن رسمی گوگل/Maven Central اول
//    می‌آیند چون سرورهای CI دسترسی مستقیم دارند و سریع‌ترند.
//
//  • روی سیستم محلی داخل ایران: میرورهای داخلی اول می‌آیند تا بیلد در شرایط
//    فیلترینگ بدون تایم‌اوت انجام شود.
//
//  تشخیص خودکار است؛ نیازی به تغییر دستی فایل نیست.
//
//  ⚠️ نکتهٔ مهم Gradle: بلوک pluginManagement باید نخستین دستور اجرایی این
//     فایل باشد. تعریف هر val یا فراخوانی قبل از آن باعث خطای
//     «Failed to apply plugin / BuildScriptProcessor» می‌شود.
// ─────────────────────────────────────────────────────────────────────────────

pluginManagement {
    val ci = System.getenv("CI") == "true" || System.getenv("GITHUB_ACTIONS") == "true"
    repositories {
        if (!ci) {
            // میرورهای داخلی (اولویت اول در ایران)
            maven("https://maven.myket.ir")
            maven("https://en-mirror.ir")
            maven("https://mirror.kargadan.ir/maven")
        }
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    val ci = System.getenv("CI") == "true" || System.getenv("GITHUB_ACTIONS") == "true"
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        if (!ci) {
            maven("https://maven.myket.ir")
            maven("https://en-mirror.ir")
            maven("https://mirror.kargadan.ir/maven")
        }
        google()
        mavenCentral()
        // JitPack: محل انتشار رسمی Poolakey (کافه‌بازار)
        maven("https://jitpack.io")
    }
}

rootProject.name = "FactorYar"

include(":app")

include(":core:common")
include(":core:domain")
include(":core:database")
include(":core:datastore")
include(":core:data")
include(":core:ui")
include(":core:pdf")
include(":core:billing")
include(":core:barcode")

include(":feature:dashboard")
include(":feature:invoices")
include(":feature:customers")
include(":feature:reports")
include(":feature:products")
include(":feature:expenses")
include(":feature:settings")
