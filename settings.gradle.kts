// ─────────────────────────────────────────────────────────────────────────────
//  پیکربندی مخازن با اولویت میرورهای داخلی ایران
//
//  ترتیب مهم است: Gradle مخازن را به‌ترتیب امتحان می‌کند، پس میرورهای داخلی
//  اول می‌آیند تا در شرایط فیلترینگ/قطعی، بیلد بدون تایم‌اوت طولانی انجام شود.
//  منابع رسمی (google/mavenCentral) در انتها به‌عنوان fallback باقی می‌مانند؛
//  اگر اینترنت بین‌الملل ندارید می‌توانید آن‌ها را کامنت کنید.
//
//  ⚠️ اگر میروری از کار افتاد، کافی است خطش را جابه‌جا یا کامنت کنید.
// ─────────────────────────────────────────────────────────────────────────────

pluginManagement {
    repositories {
        // ── میرورهای داخلی (اولویت اول) ──────────────────────────────────
        maven("https://maven.myket.ir")              // مایکت: mavenCentral + google + jitpack
        maven("https://en-mirror.ir")                // میرور گریدل/اندروید
        maven("https://gradle.jamko.ir")             // جامکو: Maven + Gradle + Android SDK
        maven("https://mirror.kargadan.ir/maven")    // کارگadan: گروه چند-میروره

        // ── منابع رسمی (Fallback) ────────────────────────────────────────
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        // ── میرورهای داخلی (اولویت اول) ──────────────────────────────────
        maven("https://maven.myket.ir")
        maven("https://en-mirror.ir")
        maven("https://gradle.jamko.ir")
        maven("https://mirror.kargadan.ir/maven")

        // ── JitPack: محل انتشار رسمی Poolakey (کافه‌بازار) ───────────────
        // مختصات صحیح: com.github.cafebazaar.Poolakey:poolakey
        // میرورهای بالا معمولاً JitPack را هم پروکسی می‌کنند؛ این خط پشتیبان است.
        maven("https://jitpack.io")

        // ── منابع رسمی (Fallback) ────────────────────────────────────────
        google()
        mavenCentral()
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
include(":core:printer")
include(":core:billing")
include(":core:barcode")

include(":feature:dashboard")
include(":feature:invoices")
include(":feature:customers")
include(":feature:reports")
include(":feature:products")
include(":feature:expenses")
include(":feature:settings")
