import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

// ---------------------------------------------------------------------------
// Application identity — change these two values to re-brand / re-publish.
// They can also be overridden from the command line, e.g.
//   ./gradlew assembleRelease -PapplicationId=com.example.roozi -PappName="روزی"
// ---------------------------------------------------------------------------

val rooziApplicationId: String = (project.findProperty("applicationId") as String?) ?: "com.roozi.app"
val rooziAppName: String = (project.findProperty("appName") as String?) ?: "ROOZI"

// Read once, outside android { }. NOTE: `java` is a Gradle extension name, so
// java.util.* must be imported explicitly rather than fully qualified here.
val keystoreProps: Properties? =
    rootProject.file("keystore.properties").takeIf { it.exists() }?.let { file ->
        Properties().apply { file.inputStream().use { stream -> load(stream) } }
    }

android {
    namespace = "com.roozi.app"
    compileSdk = 35

    defaultConfig {
        applicationId = rooziApplicationId
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        // The launcher label comes from the localized app_name resource; the
        // -PappName override is applied as a resValue so it works for both locales.
        resValue("string", "app_name_override", rooziAppName)

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables { useSupportLibrary = true }
    }

    // Optional release signing. The config is only created when
    // keystore.properties exists — an empty signingConfig is rejected by AGP,
    // so CI (which has no keystore) must not declare one at all.
    // NOTE: inside android { } the name `java` resolves to AGP's own `java`
    // property, so java.util.Properties cannot be referenced here. The keystore
    // is therefore read outside the android block (see `keystoreProps` above).

    if (keystoreProps != null) {
        signingConfigs {
            create("releaseConfig") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

            // A release build MUST always be signed: Android refuses to install
            // an unsigned APK ("package invalid" / "problem parsing the
            // package"). With a real keystore we use it; otherwise we fall back
            // to the debug key so CI artifacts stay installable for testing.
            signingConfig = if (keystoreProps != null) {
                signingConfigs.getByName("releaseConfig")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        debug {
            applicationIdSuffix = ".debug"
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions { jvmTarget = "17" }

    buildFeatures { compose = true }

    packaging {
        resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    }
}


dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.splashscreen)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons)
    debugImplementation(libs.androidx.compose.ui.tooling)

    implementation(libs.androidx.navigation.compose)

    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.work.runtime.ktx)
    implementation(libs.kotlinx.coroutines.android)

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.3")

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
}

// Guard: an unsigned release APK cannot be installed, so make that state a
// build failure rather than a broken download.
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        val signed = runCatching { variant.signingConfig?.hasConfig()?.get() }.getOrNull()
        if (signed == false) {
            throw GradleException(
                "Release variant '" + variant.name + "' has no signing config: the APK " +
                    "would be unsigned and Android would reject it as an invalid package."
            )
        }
    }
}
