plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.ksp) apply false
}

// ---------------------------------------------------------------------------
// CI diagnostics
//
// Raw Actions logs are not always reachable (artifact/blob downloads can be
// blocked by a restricted network), but *annotations* are exposed through the
// REST API. So on CI we re-emit Kotlin compiler diagnostics and test failures
// as `::error::` workflow commands, which makes them readable without the log.
// This is inert locally: it only activates when CI=true.
// ---------------------------------------------------------------------------
val isCi = providers.environmentVariable("CI").orNull == "true"

if (isCi) {
    subprojects {
        // Kotlin compiler diagnostics -> annotations. Uses the generic Task API
        // plus a logging listener so no Kotlin-plugin types are needed here.
        tasks.matching { it.name.startsWith("compile") && it.name.endsWith("Kotlin") }
            .configureEach {
                logging.addStandardErrorListener { output ->
                    output.lineSequence()
                        .filter { it.startsWith("e: ") }
                        .take(40)
                        .forEach { line ->
                            println("::error::" + line.replace("%", "%25").take(600))
                        }
                }
                logging.addStandardOutputListener { output ->
                    output.lineSequence()
                        .filter { it.startsWith("e: ") }
                        .take(40)
                        .forEach { line ->
                            println("::error::" + line.replace("%", "%25").take(600))
                        }
                }
            }

        // Unit test failures -> workflow annotations carrying the assertion message.
        tasks.withType(Test::class.java).configureEach {
            testLogging {
                events("failed")
                showStackTraces = true
                showExceptions = true
                exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
            }
            afterTest(
                KotlinClosure2<org.gradle.api.tasks.testing.TestDescriptor, org.gradle.api.tasks.testing.TestResult, Unit>(
                    { descriptor, result ->
                        if (result.resultType == org.gradle.api.tasks.testing.TestResult.ResultType.FAILURE) {
                            val cause = result.exception?.toString()
                                ?.replace(Regex("[\\r\\n]+"), " ")
                                ?.take(400)
                                ?: "unknown failure"
                            logger.lifecycle("::error::TEST FAILED " + descriptor.className + "." + descriptor.name + " :: " + cause)
                        }
                    }
                )
            )
        }
    }

    // Any failing task -> annotation naming the task and its cause chain, so the
    // failing phase is identifiable even when the log cannot be downloaded.

    gradle.taskGraph.afterTask {
        val failure = state.failure
        if (failure != null) {
            val msg = generateSequence(failure as Throwable) { it.cause }
                .mapNotNull { it.message }
                .joinToString(" | ")
                .replace(Regex("[\\r\\n]+"), " ")
                .take(700)
            logger.lifecycle("::error::TASK FAILED " + path + " :: " + msg)
        }
    }
}
