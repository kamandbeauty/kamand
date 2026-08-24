package com.modir.forushgah.presentation.orders

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.local.dao.OrderWithCustomer
import com.modir.forushgah.data.repository.OrderRepository
import com.modir.forushgah.domain.model.OrderStatus
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class OrderListUiState(
    val isLoading: Boolean = true,
    val query: String = "",
    val selectedStatus: OrderStatus? = null,
    val orders: List<OrderWithCustomer> = emptyList(),
) {
    val isEmpty: Boolean get() = !isLoading && orders.isEmpty() && query.isBlank() && selectedStatus == null
}

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class OrderListViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
) : ViewModel() {

    private val query = MutableStateFlow("")
    private val selectedStatus = MutableStateFlow<OrderStatus?>(null)

    private val orders = combine(query, selectedStatus) { q, status -> q to status }
        .flatMapLatest { (q, status) -> orderRepository.observeOrders(status = status, query = q) }

    val uiState: StateFlow<OrderListUiState> = combine(query, selectedStatus, orders) { q, status, list ->
        OrderListUiState(isLoading = false, query = q, selectedStatus = status, orders = list)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), OrderListUiState())

    fun onQueryChange(value: String) {
        query.value = value
    }

    fun onStatusSelected(status: OrderStatus?) {
        selectedStatus.value = status
    }
}
