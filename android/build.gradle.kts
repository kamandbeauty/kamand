allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.value(
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
)

subprojects {
    project.layout.buildDirectory.value(
        rootProject.layout.buildDirectory
            .dir(project.name)
            .get()
    )
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force a modern compileSdk for every Android module (including plugins).
// Some older plugin versions declare compileSdk < 33, whose platform lacks
// android:attr/lStar referenced by newer AndroidX artifacts (AAPT error
// "resource android:attr/lStar not found").
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 36
        }
    }
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.gradle.ApplicationExtension> {
            compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
