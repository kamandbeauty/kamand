package com.modir.forushgah.presentation.customers

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.PartyProfileRepository
import com.modir.forushgah.domain.model.CustomerProfile
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CustomerDetailUiState(
    val isLoading: Boolean = true,
    val profile: CustomerProfile? = null,
)

@HiltViewModel
class CustomerDetailViewModel @Inject constructor(
    private val partyProfileRepository: PartyProfileRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val customerId: Long = checkNotNull(savedStateHandle["customerId"])

    private val _state = MutableStateFlow(CustomerDetailUiState())
    val state: StateFlow<CustomerDetailUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            val profile = partyProfileRepository.getCustomerProfile(customerId)
            _state.value = CustomerDetailUiState(isLoading = false, profile = profile)
        }
    }
}
