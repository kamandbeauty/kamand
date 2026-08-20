pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk")
            ?: throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
    }

    // پلاگین Gradle فلاتر از داخل SDK می‌آید (نه ریشهٔ SDK).
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

rootProject.name = "hokm"
include(":app")

// ---------------------------------------------------------------------------
// تشخیص CI (این اسکریپت همیشه لود می‌شود، حتی اگر :app شکست بخورد)
//
// لاگ خام Actions/artifact از هر محیطی در دسترس نیست، اما annotationهای
// workflow از طریق REST API خوانا هستند. بازتاب زنجیرهٔ خطا به صورت
// ::error:: باعث می‌شود هرگونه شکست بیلد بدون نیاز به لاگ قابل‌تشخیص باشد.
// بیرون از CI (متغیر CI != "true") کاملاً خنثی است.
// ---------------------------------------------------------------------------
if (System.getenv("CI") == "true") {
    gradle.buildFinished {
        val root = failure
        if (root != null) {
            var t: Throwable? = root
            var index = 0
            while (t != null && index < 8) {
                val message = t.javaClass.simpleName + ": " + (t.message ?: "")
                val clean = message
                    .replace("\r", " ")
                    .replace("\n", " ")
                    .replace("%", "%25")
                    .take(600)
                println("::error::[" + index + "] " + clean)
                t = t.cause
                index++
            }
        }
    }
}
