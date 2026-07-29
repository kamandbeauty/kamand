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
        // میرور داخلی برای شرایط قطعی/فیلترینگ Maven گوگل
        maven("https://maven.myket.ir/artifactory/maven-public/")
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // مخزن کافه‌بازار برای Poolakey (پرداخت درون‌برنامه‌ای)
        maven("https://maven.cafebazaar.ir/artifactory/maven-public/")
        // میرور داخلی (Fallback)
        maven("https://maven.myket.ir/artifactory/maven-public/")
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
