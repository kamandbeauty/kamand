package com.modir.forushgah.presentation.orders

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.repository.OrderDetail
import com.modir.forushgah.data.repository.OrderRepository
import com.modir.forushgah.data.repository.ReferenceDataRepository
import com.modir.forushgah.data.repository.ReturnItemDraft
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.PaymentMethod
import com.modir.forushgah.domain.model.ReturnReason
import com.modir.forushgah.domain.model.ReturnStatus
import com.modir.forushgah.domain.model.SalesChannel
import com.modir.forushgah.domain.model.ShippingProvider
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class OrderDetailUiState(
    val isLoading: Boolean = true,
    val detail: OrderDetail? = null,
    val salesChannels: List<SalesChannel> = emptyList(),
    val shippingProviders: List<ShippingProvider> = emptyList(),
    val paymentMethods: List<PaymentMethod> = emptyList(),
)

sealed interface OrderDetailEvent {
    data class Success(val message: String) : OrderDetailEvent
    data class Error(val message: String) : OrderDetailEvent
}

@HiltViewModel
class OrderDetailViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val referenceDataRepository: ReferenceDataRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val orderId: Long = checkNotNull(savedStateHandle["orderId"])

    val uiState: StateFlow<OrderDetailUiState> = combine(
        orderRepository.observeDetail(orderId),
        referenceDataRepository.observeSalesChannels(),
        referenceDataRepository.observeShippingProviders(),
        referenceDataRepository.observePaymentMethods(),
    ) { detail, channels, providers, methods ->
        OrderDetailUiState(
            isLoading = false,
            detail = detail,
            salesChannels = channels,
            shippingProviders = providers,
            paymentMethods = methods,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), OrderDetailUiState())

    private val _event = MutableStateFlow<OrderDetailEvent?>(null)
    val event: StateFlow<OrderDetailEvent?> = _event.asStateFlow()

    fun consumeEvent() {
        _event.value = null
    }

    fun setStatus(status: OrderStatus) {
        viewModelScope.launch {
            try {
                orderRepository.updateStatus(orderId, status)
            } catch (e: Exception) {
                _event.value = OrderDetailEvent.Error(e.message ?: "تغییر وضعیت با خطا مواجه شد")
            }
        }
    }

    /** Spec §20: cancels and restores inventory (idempotent in the repository). */
    fun cancel() {
        viewModelScope.launch {
            try {
                orderRepository.cancelOrder(orderId)
                _event.value = OrderDetailEvent.Success("سفارش لغو شد و موجودی کالاهای آن برگشت خورد")
            } catch (e: Exception) {
                _event.value = OrderDetailEvent.Error(e.message ?: "لغو سفارش با خطا مواجه شد")
            }
        }
    }

    /** Spec §18: full or partial payment; overpayment is rejected. */
    fun recordPayment(amount: Money, method: String, paymentMethodId: Long?, reference: String?, note: String?) {
        viewModelScope.launch {
            try {
                orderRepository.recordPayment(orderId, amount, method, paymentMethodId, reference, note)
                _event.value = OrderDetailEvent.Success("پرداخت ثبت شد")
            } catch (e: IllegalArgumentException) {
                _event.value = OrderDetailEvent.Error(e.message ?: "ثبت پرداخت با خطا مواجه شد")
            } catch (e: Exception) {
                _event.value = OrderDetailEvent.Error(e.message ?: "ثبت پرداخت با خطا مواجه شد")
            }
        }
    }

    /** Spec §21–§23: full/partial return with per-item quantities. */
    fun createReturn(
        items: List<ReturnItemDraft>,
        reason: ReturnReason,
        returnShippingCost: Money,
        packagingCostLost: Money,
        restockedToInventory: Boolean,
    ) {
        viewModelScope.launch {
            try {
                orderRepository.createReturn(
                    orderId = orderId,
                    items = items,
                    reason = reason,
                    returnShippingCost = returnShippingCost,
                    packagingCostLost = packagingCostLost,
                    restockedToInventory = restockedToInventory,
                )
                _event.value = OrderDetailEvent.Success("مرجوعی ثبت شد")
            } catch (e: IllegalArgumentException) {
                _event.value = OrderDetailEvent.Error(e.message ?: "ثبت مرجوعی با خطا مواجه شد")
            } catch (e: Exception) {
                _event.value = OrderDetailEvent.Error(e.message ?: "ثبت مرجوعی با خطا مواجه شد")
            }
        }
    }

    fun setReturnStatus(returnId: Long, status: ReturnStatus) {
        viewModelScope.launch {
            try {
                orderRepository.setReturnStatus(returnId, status)
            } catch (e: Exception) {
                _event.value = OrderDetailEvent.Error(e.message ?: "تغییر وضعیت مرجوعی با خطا مواجه شد")
            }
        }
    }

    /** Spec §24: refund — original payments are preserved. */
    fun createRefund(amount: Money, method: String, reason: String, note: String?) {
        viewModelScope.launch {
            try {
                orderRepository.createRefund(orderId, amount, method, reason, note)
                _event.value = OrderDetailEvent.Success("استرداد ثبت شد")
            } catch (e: IllegalArgumentException) {
                _event.value = OrderDetailEvent.Error(e.message ?: "ثبت استرداد با خطا مواجه شد")
            } catch (e: Exception) {
                _event.value = OrderDetailEvent.Error(e.message ?: "ثبت استرداد با خطا مواجه شد")
            }
        }
    }
}
