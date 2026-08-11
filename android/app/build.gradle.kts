import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

/*
 * Release signing is deliberately opt-in. Values are read in this order:
 *
 *   1. RELEASE_* environment variables (recommended for CI)
 *   2. android/key.properties (local file, ignored by Git)
 *   3. android/local.properties using release.* keys (local fallback)
 *
 * Passwords are never stored in this build script and are never printed.
 */
fun loadPropertiesIfPresent(file: File): Properties {
    val properties = Properties()
    if (file.isFile) {
        FileInputStream(file).use { properties.load(it) }
    }
    return properties
}

val releaseProperties = loadPropertiesIfPresent(rootProject.file("key.properties"))
val localProperties = loadPropertiesIfPresent(rootProject.file("local.properties"))

fun configuredValue(
    environmentName: String,
    propertyName: String,
): String? {
    return sequenceOf(
        System.getenv(environmentName),
        releaseProperties.getProperty(propertyName),
        localProperties.getProperty("release.$propertyName"),
        localProperties.getProperty(propertyName),
    ).mapNotNull { value ->
        value?.trim()?.takeIf { it.isNotEmpty() }
    }.firstOrNull()
}

val releaseStoreFileValue = configuredValue("RELEASE_STORE_FILE", "storeFile")
val releaseStorePassword = configuredValue("RELEASE_STORE_PASSWORD", "storePassword")
val releaseKeyAlias = configuredValue("RELEASE_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = configuredValue("RELEASE_KEY_PASSWORD", "keyPassword")

val missingReleaseValues = buildList {
    if (releaseStoreFileValue == null) add("RELEASE_STORE_FILE")
    if (releaseStorePassword == null) add("RELEASE_STORE_PASSWORD")
    if (releaseKeyAlias == null) add("RELEASE_KEY_ALIAS")
    if (releaseKeyPassword == null) add("RELEASE_KEY_PASSWORD")
}

val releaseStoreFile = releaseStoreFileValue?.let { rawPath ->
    val path = File(rawPath)
    if (path.isAbsolute) path else rootProject.file(rawPath)
}

val releaseSigningConfigured =
    missingReleaseValues.isEmpty() && releaseStoreFile?.isFile == true

val releaseSigningError = when {
    missingReleaseValues.isNotEmpty() -> {
        """
        Release signing credentials are not configured.
        Set RELEASE_STORE_FILE, RELEASE_STORE_PASSWORD, RELEASE_KEY_ALIAS and RELEASE_KEY_PASSWORD,
        or configure the ignored android/key.properties file.
        Missing: ${missingReleaseValues.joinToString(", ")}
        """.trimIndent()
    }

    releaseStoreFile?.isFile != true -> {
        """
        Release signing keystore file was not found.
        Check RELEASE_STORE_FILE or storeFile in android/key.properties.
        """.trimIndent()
    }

    else -> null
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
        if (releaseSigningConfigured) {
            create("release") {
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
                storeFile = releaseStoreFile!!
                storePassword = releaseStorePassword!!
            }
        }
    }

    buildTypes {
        named("release") {
            // Release must never silently fall back to the debug certificate.
            isDebuggable = false
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }

            // R8/resource shrinking stays disabled until the app is tested with it.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

/*
 * Keep debug builds independent from the release keystore, but fail release
 * tasks early with an actionable message when the credentials are absent.
 */
val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    doLast {
        if (!releaseSigningConfigured) {
            throw org.gradle.api.GradleException(
                releaseSigningError ?: "Release signing credentials are not configured.",
            )
        }
    }
}

tasks.configureEach {
    if (name.contains("Release") && name != "verifyReleaseSigning") {
        dependsOn(verifyReleaseSigning)
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
