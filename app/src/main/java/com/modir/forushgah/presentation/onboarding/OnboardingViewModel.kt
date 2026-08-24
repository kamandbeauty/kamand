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
                startingCashBalance = Money(state.startingCash.toLongOrNull() ?: 0L),
            )
            onDone()
        }
    }
}
