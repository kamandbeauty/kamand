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
    val keystoreProps = rootProject.file("keystore.properties").takeIf { it.exists() }?.let { file ->
        java.util.Properties().apply { file.inputStream().use { load(it) } }
    }

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
            if (keystoreProps != null) {
                signingConfig = signingConfigs.getByName("releaseConfig")
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

// Configuration-phase probe (CI only): if this annotation is missing from a run,
// the :app build script failed to configure.
if (providers.environmentVariable("CI").orNull == "true") {
    logger.lifecycle("::warning::APP-CONFIG-OK app build script configured")
}
