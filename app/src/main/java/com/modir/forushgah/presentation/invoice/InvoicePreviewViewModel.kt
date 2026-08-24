package com.modir.forushgah.presentation.invoice

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.OrderDetail
import com.modir.forushgah.data.repository.OrderRepository
import com.modir.forushgah.data.repository.StoreProfileRepository
import com.modir.forushgah.domain.model.StoreProfile
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class InvoicePreviewUiState(
    val isLoading: Boolean = true,
    val detail: OrderDetail? = null,
    val store: StoreProfile? = null,
)

/** Rubi invoice preview (Phase 3.1) — live data from the Phase 3 engine. */
@HiltViewModel
class InvoicePreviewViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val storeProfileRepository: StoreProfileRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val orderId: Long = checkNotNull(savedStateHandle["orderId"])

    val uiState: StateFlow<InvoicePreviewUiState> = combine(
        orderRepository.observeDetail(orderId),
        storeProfileRepository.observeStore(),
    ) { detail, store ->
        InvoicePreviewUiState(isLoading = false, detail = detail, store = store)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), InvoicePreviewUiState())

    companion object {
        fun routeFor(orderId: Long) = "invoice/$orderId"
    }
}
