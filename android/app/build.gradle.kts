plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// ── Release signing (key.properties) ──────────────────────────
// فایل android/key.properties را از key.properties.example بسازید.
// اگر key.properties نباشد، release با debug ساین می‌شود (فقط برای تست).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ruby.factor_ruby"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ruby.factor_ruby"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // مسیر storeFile نسبت به پوشه android/ (جایی که key.properties است)
                val storePath = keystoreProperties["storeFile"] as String
                storeFile = rootProject.file(storePath)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        named("release") {
            // اگر keystore رسمی باشد با آن ساین کن؛ وگرنه debug (هشدار ناشناخته)
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                println("⚠️  key.properties پیدا نشد — release با debug key ساین می‌شود (ناشناخته).")
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
