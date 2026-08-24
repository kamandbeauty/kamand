package com.modir.forushgah

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.StoreProfileRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class RootViewModel @Inject constructor(
    storeProfileRepository: StoreProfileRepository,
) : ViewModel() {

    /** null = still loading from DB, true/false = known onboarding state.
     * This is a Flow off Room, so it updates automatically the moment
     * onboarding is completed — no manual refresh is actually required,
     * but [refresh] is kept as a no-op hook for future use (e.g. re-check
     * after a settings reset). */
    val onboardingCompleted: StateFlow<Boolean?> = storeProfileRepository.isOnboardingCompleted()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun refresh() { /* no-op: see kdoc above */ }
}
