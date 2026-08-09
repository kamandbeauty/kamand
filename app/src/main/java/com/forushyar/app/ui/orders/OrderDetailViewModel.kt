package com.forushyar.app.ui.orders

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.forushyar.app.data.local.entity.OrderDetails
import com.forushyar.app.data.local.entity.OrderStatus
import com.forushyar.app.data.repository.OrderRepository
import com.forushyar.app.data.repository.ProductRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class OrderDetailState(
    val details: OrderDetails? = null,
    val productNames: Map<Long, String> = emptyMap(),
    val isLoading: Boolean = true
)

sealed interface OrderDetailEvent {
    data object Deleted : OrderDetailEvent
    data object DeleteFailed : OrderDetailEvent
    data object StatusChangeFailed : OrderDetailEvent
}

@HiltViewModel
class OrderDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repository: OrderRepository,
    productRepository: ProductRepository
) : ViewModel() {

    val orderId: Long = checkNotNull(savedStateHandle.get<Long>("orderId"))

    val state: StateFlow<OrderDetailState> = combine(
        repository.observeById(orderId),
        productRepository.observeAll()
    ) { details, products ->
        OrderDetailState(
            details = details,
            productNames = products.associate { it.id to it.name },
            isLoading = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = OrderDetailState()
    )

    private val _events = Channel<OrderDetailEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()
    private var deleteInProgress = false

    fun changeStatus(status: OrderStatus) {
        if (state.value.details?.order?.status == status) return
        viewModelScope.launch {
            runCatching { repository.updateStatus(orderId, status) }
                .onFailure { _events.send(OrderDetailEvent.StatusChangeFailed) }
        }
    }

    fun deleteOrder() {
        if (deleteInProgress || state.value.details == null) return
        deleteInProgress = true
        viewModelScope.launch {
            runCatching { repository.deleteById(orderId) }
                .onSuccess { _events.send(OrderDetailEvent.Deleted) }
                .onFailure {
                    deleteInProgress = false
                    _events.send(OrderDetailEvent.DeleteFailed)
                }
        }
    }
}
