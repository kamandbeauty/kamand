package com.javidstudio.app2.ui.birthday

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.javidstudio.app2.R
import com.javidstudio.app2.data.repo.BirthdayMessages

/**
 * Personalises a greeting for a person.
 *
 * The vocative suffixes live in resources next to the greetings themselves, so
 * removing "[نام] جان،" when no name is known stays a text concern rather than
 * hardcoded grammar in Kotlin.
 */
@Composable
fun rememberPersonalized(text: String, name: String?): String {
    val suffixes = listOf(
        stringResource(R.string.name_suffix_1),
        stringResource(R.string.name_suffix_2),
        stringResource(R.string.name_suffix_3),
        stringResource(R.string.name_suffix_4),
        stringResource(R.string.name_suffix_5)
    )
    return BirthdayMessages.personalize(
        text = text,
        name = name,
        token = stringResource(R.string.name_token),
        suffixes = suffixes
    )
}
