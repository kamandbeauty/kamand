// ─────────────────────────────────────────────────────────────────────────────
//  اسکریپت Init برای اجبار همهٔ درخواست‌ها به میرورهای داخلی
//
//  چرا لازم است؟
//  بعضی پلاگین‌ها (و ماژول‌های وابسته) مخزن خودشان را داخل کد تعریف می‌کنند و
//  تنظیمات settings.gradle.kts را دور می‌زنند. این اسکریپت چون در مرحلهٔ
//  Initialization اجرا می‌شود، *قبل از* بارگذاری هر پلاگین، مخازن را پاک و
//  با میرورهای داخلی جایگزین می‌کند.
//
//  ── روش استفاده ──────────────────────────────────────────────────────────
//  الف) موقتی (فقط یک بیلد):
//       ./gradlew --init-script gradle/init.mirror.gradle.kts :app:assembleDebug
//
//  ب) دائمی (توصیه‌شده — برای همهٔ پروژه‌های اندرویدی شما):
//       این فایل را کپی کنید در:
//         لینوکس/مک:  ~/.gradle/init.d/mirror.gradle.kts
//         ویندوز:     C:\Users\<user>\.gradle\init.d\mirror.gradle.kts
//       از آن پس همهٔ بیلدها خودکار از میرور استفاده می‌کنند.
//
//  ⚠️ اگر اینترنت بین‌الملل دارید و میرورها کند بودند، این اسکریپت را استفاده
//     نکنید؛ settings.gradle.kts به‌تنهایی کافی است.
// ─────────────────────────────────────────────────────────────────────────────

val iranianMirrors = listOf(
    "https://maven.myket.ir",
    "https://en-mirror.ir",
    "https://gradle.jamko.ir",
    "https://mirror.kargadan.ir/maven",
    "https://jitpack.io", // برای Poolakey
)

settingsEvaluated {
    pluginManagement {
        repositories {
            clear()
            iranianMirrors.forEach { maven(url = it) }
            // fallback رسمی — در صورت نبود دسترسی بین‌الملل کامنت کنید
            gradlePluginPortal()
            google()
            mavenCentral()
        }
    }
    @Suppress("UnstableApiUsage")
    dependencyResolutionManagement {
        repositories {
            clear()
            iranianMirrors.forEach { maven(url = it) }
            google()
            mavenCentral()
        }
    }
}

allprojects {
    buildscript {
        repositories {
            clear()
            iranianMirrors.forEach { maven(url = it) }
            google()
            mavenCentral()
        }
    }
}
