plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

android {
    namespace = "ir.factoryar.core.barcode"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:ui"))

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons.extended)
    implementation(libs.androidx.lifecycle.runtime.compose)
    // لازم برای rememberLauncherForActivityResult (درخواست مجوز دوربین)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.core.ktx)

    // دوربین
    implementation(libs.androidx.camera.core)
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)

    // ML Kit — نسخه bundled: مدل داخل APK است و به Google Play Services نیاز ندارد
    implementation(libs.mlkit.barcode.scanning)
    // موتور جایگزین سبک برای دستگاه‌های بدون GMS یا در صورت خطای ML Kit
    implementation(libs.zxing.core)

    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
}
