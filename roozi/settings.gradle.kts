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

// ---------------------------------------------------------------------------
// CI diagnostics (settings scripts always load, even if :app fails to configure)
//
// Raw Actions logs and artifacts are not reachable from every environment, but
// workflow annotations are exposed through the REST API. Mirroring the failure
// chain here makes any build breakage diagnosable. Inert outside CI.
// ---------------------------------------------------------------------------
if (System.getenv("CI") == "true") {
    gradle.buildFinished {
        val root = failure
        if (root != null) {
            generateSequence(root as Throwable) { it.cause }
                .mapNotNull { t -> t.message?.let { "${t.javaClass.simpleName}: ${'$'}it" } }
                .take(8)
                .forEachIndexed { index, message ->
                    val clean = message
                        .replace(Regex("[\\r\\n]+"), " ")
                        .replace("%", "%25")
                        .take(600)
                    println("::error::[${'$'}index] ${'$'}clean")
                }
        }
    }
}
