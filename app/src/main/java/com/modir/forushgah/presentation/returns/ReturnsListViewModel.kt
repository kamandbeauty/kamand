package com.modir.forushgah.presentation.returns

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.local.dao.ReturnWithOrder
import com.modir.forushgah.data.repository.OrderRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class ReturnsListUiState(
    val isLoading: Boolean = true,
    val returns: List<ReturnWithOrder> = emptyList(),
)

@HiltViewModel
class ReturnsListViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
) : ViewModel() {

    val uiState: StateFlow<ReturnsListUiState> =
        orderRepository.observeReturns()
            .map { returns -> ReturnsListUiState(isLoading = false, returns = returns) }
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ReturnsListUiState())
}
