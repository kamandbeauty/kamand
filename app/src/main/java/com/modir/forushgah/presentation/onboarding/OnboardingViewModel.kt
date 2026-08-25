package com.modir.forushgah.presentation.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.repository.StoreProfileRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class OnboardingFormState(
    val storeName: String = "",
    val ownerName: String = "",
    val businessCategory: String = "",
    val startingCash: String = "",
    val isSubmitting: Boolean = false,
) {
    val canProceedFromStep1: Boolean get() = storeName.isNotBlank() && ownerName.isNotBlank()
}

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val storeProfileRepository: StoreProfileRepository,
) : ViewModel() {

    private val _formState = MutableStateFlow(OnboardingFormState())
    val formState: StateFlow<OnboardingFormState> = _formState

    fun onStoreNameChanged(value: String) { _formState.value = _formState.value.copy(storeName = value) }
    fun onOwnerNameChanged(value: String) { _formState.value = _formState.value.copy(ownerName = value) }
    fun onCategoryChanged(value: String) { _formState.value = _formState.value.copy(businessCategory = value) }
    fun onStartingCashChanged(value: String) { _formState.value = _formState.value.copy(startingCash = value.filter { it.isDigit() }) }

    fun finishOnboarding(onDone: () -> Unit) {
        val state = _formState.value
        viewModelScope.launch {
            _formState.value = state.copy(isSubmitting = true)
            storeProfileRepository.completeOnboarding(
                storeName = state.storeName,
                ownerName = state.ownerName,
                businessCategory = state.businessCategory,
                // The field is OPTIONAL: empty/whitespace/invalid input is a
                // zero starting balance — never null, never a crash.
                startingCashBalance = parseStartingCashToman(state.startingCash),
            )
            onDone()
        }
    }
}

/**
 * Parses the onboarding "موجودی نقدی اولیه" input into Toman.
 *
 * Business rule: the field is optional —
 * - empty / whitespace-only / unparsable input → [Money.ZERO],
 * - Persian digits (۰-۹) are converted to Latin digits first,
 * - a result can never be negative (clamped to zero).
 *
 * Char codes 0x06F0..0x06F9 are the Persian/Arabic-Indic digits, written as
 * numeric escapes so the source file stays pure ASCII.
 */
internal fun parseStartingCashToman(raw: String): Money {
    val latin = raw.trim()
        .map { ch -> if (ch.code in 0x06F0..0x06F9) '0' + (ch.code - 0x06F0) else ch }
        .joinToString("")
        .filter { it.isDigit() }
    return Money((latin.toLongOrNull() ?: 0L).coerceAtLeast(0L))
}
