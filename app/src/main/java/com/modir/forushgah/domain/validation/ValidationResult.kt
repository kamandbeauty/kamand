package com.modir.forushgah.domain.validation

/** Simple, composable validation result — no exceptions for expected user input errors. */
sealed interface ValidationResult {
    data object Valid : ValidationResult
    data class Invalid(val messages: List<String>) : ValidationResult
}

fun validationOf(vararg checks: Pair<Boolean, String>): ValidationResult {
    val errors = checks.filter { !it.first }.map { it.second }
    return if (errors.isEmpty()) ValidationResult.Valid else ValidationResult.Invalid(errors)
}
