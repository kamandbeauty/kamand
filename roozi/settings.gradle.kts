pluginManagement {
    repositories {
        // No content filter here: the KSP plugin marker lives on the Gradle
        // Plugin Portal / Maven Central, and over-filtering google() has caused
        // plugin resolution to fail outright.
        google()
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

rootProject.name = "ROOZI"
include(":app")
