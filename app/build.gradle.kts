import java.io.File
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

// ─────────────────────────────────────────────────────────────────────────────
//  پیکربندی امضای نسخه Release
//
//  کلید امضا هرگز داخل مخزن قرار نمی‌گیرد. مقادیر از دو منبع خوانده می‌شوند:
//    ۱) متغیرهای محیطی (GitHub Actions → از Secrets)
//    ۲) فایل keystore.properties در ریشه (توسعهٔ محلی — در .gitignore است)
//
//  اگر هیچ‌کدام موجود نباشد، بیلد release با امضای debug انجام می‌شود تا
//  CI بدون Secrets هم بتواند کامپایل را تست کند.
// ─────────────────────────────────────────────────────────────────────────────
val keystoreProps = Properties()
val keystorePropsFile = rootProject.file("keystore.properties")
if (keystorePropsFile.exists()) {
    keystorePropsFile.inputStream().use { stream -> keystoreProps.load(stream) }
}

// خواندن مقدار از متغیر محیطی (CI) یا فایل محلی
val storeFilePath: String? =
    System.getenv("KEYSTORE_FILE") ?: keystoreProps.getProperty("storeFile")
val storePasswordValue: String? =
    System.getenv("KEYSTORE_PASSWORD") ?: keystoreProps.getProperty("storePassword")
val keyAliasValue: String? =
    System.getenv("KEY_ALIAS") ?: keystoreProps.getProperty("keyAlias")
val keyPasswordValue: String? =
    System.getenv("KEY_PASSWORD") ?: keystoreProps.getProperty("keyPassword")

// توجه: بررسی وجود فایل فقط وقتی مسیر غیرخالی است، وگرنه file(null) خطا می‌دهد
val hasReleaseSigning: Boolean = !storeFilePath.isNullOrBlank() &&
    !storePasswordValue.isNullOrBlank() &&
    !keyAliasValue.isNullOrBlank() &&
    !keyPasswordValue.isNullOrBlank() &&
    File(storeFilePath).exists()

android {
    namespace = "ir.factoryar.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "ir.factoryar.app"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        vectorDrawables { useSupportLibrary = true }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(storeFilePath!!)
                storePassword = storePasswordValue
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // بدون کلید امضا (مثلاً CI بدون Secrets) → امضای debug
                // تا کامپایل قابل تست باشد. این APK قابل انتشار نیست.
                signingConfigs.getByName("debug")
            }
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    buildFeatures {
        compose = true
        buildConfig = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // ─────────────────────────────────────────────────────────────────────
    //  کاهش حجم APK
    //
    //  بخش عمدهٔ حجم از کتابخانه‌های نیتیو می‌آید: SQLCipher (رمزنگاری)،
    //  ML Kit (مدل bundled بارکد) و CameraX. هر کدام برای چند معماری
    //  پردازنده کامپایل شده‌اند.
    //
    //  با splits، به‌جای یک APK فراگیر، چند APK جداگانه ساخته می‌شود و
    //  هر دستگاه فقط سهم خودش را دریافت می‌کند (تقریباً نصف حجم).
    //  کافه‌بازار و مایکت هر دو آپلود چند APK را پشتیبانی می‌کنند.
    // ─────────────────────────────────────────────────────────────────────
    splits {
        abi {
            isEnable = true
            reset()
            // arm64 و armeabi پوشش‌دهندهٔ تقریباً همهٔ گوشی‌های واقعی‌اند
            include("armeabi-v7a", "arm64-v8a")
            // یک APK فراگیر هم ساخته می‌شود برای مواقعی که آپلود تکی لازم است
            isUniversalApk = true
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "/META-INF/{AL2.0,LGPL2.1}",
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
            )
        }
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:domain"))
    implementation(project(":core:database"))
    implementation(project(":core:datastore"))
    implementation(project(":core:data"))
    implementation(project(":core:ui"))
    implementation(project(":core:pdf"))
    implementation(project(":core:billing"))
    implementation(project(":core:barcode"))

    implementation(project(":feature:dashboard"))
    implementation(project(":feature:invoices"))
    implementation(project(":feature:customers"))
    implementation(project(":feature:reports"))
    implementation(project(":feature:products"))
    implementation(project(":feature:expenses"))
    implementation(project(":feature:settings"))

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.splashscreen)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons.extended)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.hilt.navigation.compose)

    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)

    // ویجت صفحه اصلی (Glance)
    implementation(libs.androidx.glance.appwidget)
    implementation(libs.androidx.glance.material3)

    implementation(libs.androidx.work.runtime.ktx)
    implementation(libs.androidx.hilt.work)
    ksp(libs.androidx.hilt.compiler)

    implementation(libs.kotlinx.coroutines.android)
}
