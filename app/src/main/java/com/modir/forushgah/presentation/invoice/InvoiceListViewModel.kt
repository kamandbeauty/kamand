package com.modir.forushgah.presentation.invoice

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.isPositive
import com.modir.forushgah.data.local.dao.OrderWithCustomer
import com.modir.forushgah.data.repository.OrderRepository
import com.modir.forushgah.domain.model.OrderKind
import com.modir.forushgah.domain.model.OrderStatus
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** One invoice row (Rubi list): identity + total + payment status. */
data class InvoiceRowUi(
    val id: Long,
    val number: String,
    val partyName: String, // customer (sales) or supplier (purchase)
    val date: Long,
    val itemCount: Int,
    val total: Money,
    val isPurchase: Boolean,
    val isCancelled: Boolean,
    val paid: Money,
) {
    /** Rubi pill: paid / partial / unpaid / cancelled (proforma is not
     * produced by the create flow, so it never appears). */
    val statusLabel: String
        get() = when {
            isCancelled -> "لغو شده"
            paid >= total -> "پرداخت شده"
            paid.isPositive -> "پرداخت ناقص"
            else -> "پرداخت نشده"
        }

    val statusColor: InvoiceRowUiStatus
        get() = when {
            isCancelled -> InvoiceRowUiStatus.CANCELLED
            paid >= total -> InvoiceRowUiStatus.PAID
            paid.isPositive -> InvoiceRowUiStatus.PARTIAL
            else -> InvoiceRowUiStatus.UNPAID
        }
}

enum class InvoiceRowUiStatus { PAID, PARTIAL, UNPAID, CANCELLED }

data class InvoiceListUiState(
    val isLoading: Boolean = true,
    val invoices: List<InvoiceRowUi> = emptyList(),
    val message: String? = null,
)

@HiltViewModel
class InvoiceListViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
) : ViewModel() {

    private val message = MutableStateFlow<String?>(null)

    val uiState: StateFlow<InvoiceListUiState> = combine(
        orderRepository.observeOrders().map { rows -> rows.map { it.toRow() } },
        message,
    ) { invoices, msg ->
        InvoiceListUiState(isLoading = false, invoices = invoices, message = msg)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), InvoiceListUiState())

    fun onMessageShown() {
        message.value = null
    }

    /** Rubi list action «کپی فاکتور»: a real new invoice under the next number
     * (inventory is affected again — an oversell fails the copy). */
    fun copyInvoice(orderId: Long) {
        viewModelScope.launch {
            try {
                val copied = orderRepository.copyOrder(orderId)
                message.value = "فاکتور کپی شد؛ شماره ${copied.orderNumber}"
            } catch (e: Exception) {
                message.value = "کپی ناموفق بود: ${e.message}"
            }
        }
    }

    /** Rubi list action «حذف فاکتور»: stock impact reversed, then deleted. */
    fun deleteInvoice(orderId: Long) {
        viewModelScope.launch {
            try {
                orderRepository.deleteOrder(orderId)
                message.value = "فاکتور حذف شد"
            } catch (e: Exception) {
                message.value = "حذف ناموفق بود: ${e.message}"
            }
        }
    }
}

private fun OrderWithCustomer.toRow(): InvoiceRowUi = InvoiceRowUi(
    id = order.id,
    number = order.orderNumber,
    partyName = customerName?.takeIf { it.isNotBlank() } ?: supplierName.orEmpty(),
    date = order.orderDate,
    itemCount = itemCount,
    total = totalCustomerPayment,
    isPurchase = order.kind == OrderKind.PURCHASE,
    isCancelled = order.status == OrderStatus.CANCELLED,
    paid = Money(paidAmount),
)
