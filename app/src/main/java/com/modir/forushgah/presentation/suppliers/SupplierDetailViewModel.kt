package com.modir.forushgah.presentation.suppliers

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.PartyProfileRepository
import com.modir.forushgah.data.repository.SupplierRepository
import com.modir.forushgah.domain.model.SupplierProfile
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SupplierDetailUiState(
    val isLoading: Boolean = true,
    val profile: SupplierProfile? = null,
)

sealed interface SupplierDetailEvent {
    data object Archived : SupplierDetailEvent
    data class Error(val message: String) : SupplierDetailEvent
}

@HiltViewModel
class SupplierDetailViewModel @Inject constructor(
    private val partyProfileRepository: PartyProfileRepository,
    private val supplierRepository: SupplierRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val supplierId: Long = checkNotNull(savedStateHandle["supplierId"])

    private val _state = MutableStateFlow(SupplierDetailUiState())
    val state: StateFlow<SupplierDetailUiState> = _state.asStateFlow()

    private val _event = MutableStateFlow<SupplierDetailEvent?>(null)
    val event: StateFlow<SupplierDetailEvent?> = _event.asStateFlow()

    init {
        viewModelScope.launch {
            val profile = partyProfileRepository.getSupplierProfile(supplierId)
            _state.value = SupplierDetailUiState(isLoading = false, profile = profile)
        }
    }

    fun archiveSupplier() {
        viewModelScope.launch {
            try {
                supplierRepository.archive(supplierId)
                _event.value = SupplierDetailEvent.Archived
            } catch (e: Exception) {
                _event.value = SupplierDetailEvent.Error(e.message ?: "بایگانی تأمین‌کننده با خطا مواجه شد")
            }
        }
    }

    fun consumeEvent() {
        _event.value = null
    }
}
