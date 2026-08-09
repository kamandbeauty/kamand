package com.forushyar.app.ui.customers

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.forushyar.app.data.local.entity.Customer
import com.forushyar.app.data.local.entity.OrderWithItems
import com.forushyar.app.data.repository.CustomerRepository
import com.forushyar.app.data.repository.OrderRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class CustomerDetailState(
    val customer: Customer? = null,
    val orders: List<OrderWithItems> = emptyList(),
    val isLoading: Boolean = true
)

sealed interface CustomerDetailEvent {
    data object Deleted : CustomerDetailEvent
    data object DeleteFailed : CustomerDetailEvent
}

@HiltViewModel
class CustomerDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val customerRepository: CustomerRepository,
    orderRepository: OrderRepository
) : ViewModel() {

    val customerId: Long = checkNotNull(savedStateHandle.get<Long>("customerId"))

    val state: StateFlow<CustomerDetailState> = combine(
        customerRepository.observeById(customerId),
        orderRepository.observeByCustomer(customerId)
    ) { customer, orders ->
        CustomerDetailState(customer = customer, orders = orders, isLoading = false)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = CustomerDetailState()
    )

    private val _events = Channel<CustomerDetailEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()
    private var deleteInProgress = false

    fun deleteCustomer() {
        val customer = state.value.customer ?: return
        if (deleteInProgress) return
        deleteInProgress = true
        viewModelScope.launch {
            runCatching { customerRepository.delete(customer) }
                .onSuccess { _events.send(CustomerDetailEvent.Deleted) }
                .onFailure {
                    deleteInProgress = false
                    _events.send(CustomerDetailEvent.DeleteFailed)
                }
        }
    }
}
