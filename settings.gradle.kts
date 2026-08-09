// =====================================================================
// فروشیار (ForushYar) — تنظیمات پروژه
//
// نکته برای کاربران ایران:
// این پروژه از Repositoryهای استاندارد Google Maven و Maven Central
// استفاده می‌کند. اگر در محیط شما به این مخزن‌ها دسترسی ندارید، می‌توانید
// از طریق فایل ~/.gradle/init.gradle یا تنظیم mirror داخل مخزن،
// Repositoryهای ایرانی/آینه‌ای (مثل آینه‌ی Maven) را اضافه کنید.
// =====================================================================
pluginManagement {
    repositories {
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
        google()
        mavenCentral()
    }
}

rootProject.name = "ForushYar"
include(":app")
