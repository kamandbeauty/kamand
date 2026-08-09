package com.forushyar.app.ui.orders

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.forushyar.app.data.local.entity.Customer
import com.forushyar.app.data.local.entity.OrderItem
import com.forushyar.app.data.local.entity.Product
import com.forushyar.app.data.repository.CustomerRepository
import com.forushyar.app.data.repository.OrderRepository
import com.forushyar.app.data.repository.ProductRepository
import com.forushyar.app.util.FormatUtils
import com.forushyar.app.util.toNonNegativeLongOrNull
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch

data class OrderDraftItem(
    val productId: Long,
    val productName: String,
    val availableStock: Int,
    val quantity: Int = 1,
    val buyPrice: String,
    val sellPrice: String
) {
    val total: Long
        get() = (sellPrice.toNonNegativeLongOrNull() ?: 0) * quantity
}

enum class OrderFormError {
    CUSTOMER_REQUIRED,
    ITEMS_REQUIRED,
    INVALID_ITEM
}

data class OrderFormState(
    val customers: List<Customer> = emptyList(),
    val products: List<Product> = emptyList(),
    val customerId: Long? = null,
    val items: List<OrderDraftItem> = emptyList(),
    val note: String = "",
    val isSaving: Boolean = false,
    val error: OrderFormError? = null
) {
    val selectedCustomer: Customer?
        get() = customers.firstOrNull { it.id == customerId }
    val total: Long
        get() = items.sumOf { it.total }
}

sealed interface OrderFormEvent {
    data class Saved(val orderId: Long) : OrderFormEvent
    data object SaveFailed : OrderFormEvent
}

@HiltViewModel
class OrderFormViewModel @Inject constructor(
    customerRepository: CustomerRepository,
    productRepository: ProductRepository,
    private val orderRepository: OrderRepository
) : ViewModel() {

    private val _state = MutableStateFlow(OrderFormState())
    val state: StateFlow<OrderFormState> = _state.asStateFlow()

    private val _events = Channel<OrderFormEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()

    init {
        viewModelScope.launch {
            combine(customerRepository.observeAll(), productRepository.observeAll()) { customers, products ->
                customers to products
            }.collect { (customers, products) ->
                _state.value = _state.value.copy(customers = customers, products = products)
            }
        }
    }

    fun selectCustomer(customerId: Long) {
        _state.value = _state.value.copy(customerId = customerId, error = null)
    }

    fun addProduct(product: Product) {
        val current = _state.value
        val existing = current.items.firstOrNull { it.productId == product.id }
        val items = if (existing == null) {
            current.items + OrderDraftItem(
                productId = product.id,
                productName = product.name,
                availableStock = product.stock,
                buyPrice = FormatUtils.formatNumber(product.buyPrice),
                sellPrice = FormatUtils.formatNumber(product.sellPrice)
            )
        } else {
            current.items.map {
                if (it.productId == product.id) it.copy(quantity = it.quantity + 1) else it
            }
        }
        _state.value = current.copy(items = items, error = null)
    }

    fun removeProduct(productId: Long) {
        _state.value = _state.value.copy(
            items = _state.value.items.filterNot { it.productId == productId },
            error = null
        )
    }

    fun changeQuantity(productId: Long, amount: Int) {
        _state.value = _state.value.copy(
            items = _state.value.items.map { item ->
                if (item.productId == productId) {
                    item.copy(quantity = (item.quantity + amount).coerceAtLeast(1))
                } else item
            },
            error = null
        )
    }

    fun changeBuyPrice(productId: Long, value: String) = updateItem(productId) { copy(buyPrice = value) }
    fun changeSellPrice(productId: Long, value: String) = updateItem(productId) { copy(sellPrice = value) }
    fun changeNote(value: String) { _state.value = _state.value.copy(note = value) }

    private fun updateItem(productId: Long, block: OrderDraftItem.() -> OrderDraftItem) {
        _state.value = _state.value.copy(
            items = _state.value.items.map { if (it.productId == productId) it.block() else it },
            error = null
        )
    }

    fun save() {
        val current = _state.value
        val error = when {
            current.customerId == null -> OrderFormError.CUSTOMER_REQUIRED
            current.items.isEmpty() -> OrderFormError.ITEMS_REQUIRED
            current.items.any {
                it.quantity < 1 || it.buyPrice.toNonNegativeLongOrNull() == null ||
                    it.sellPrice.toNonNegativeLongOrNull() == null
            } -> OrderFormError.INVALID_ITEM
            else -> null
        }
        if (error != null) {
            _state.value = current.copy(error = error)
            return
        }
        if (current.isSaving) return

        viewModelScope.launch {
            _state.value = current.copy(isSaving = true, error = null)
            val items = current.items.map {
                OrderItem(
                    orderId = 0,
                    productId = it.productId,
                    quantity = it.quantity,
                    buyPrice = checkNotNull(it.buyPrice.toNonNegativeLongOrNull()),
                    sellPrice = checkNotNull(it.sellPrice.toNonNegativeLongOrNull())
                )
            }
            runCatching {
                orderRepository.createOrder(
                    customerId = checkNotNull(current.customerId),
                    note = current.note.trim(),
                    items = items
                )
            }.onSuccess { orderId ->
                _events.send(OrderFormEvent.Saved(orderId))
            }.onFailure {
                _state.value = _state.value.copy(isSaving = false)
                _events.send(OrderFormEvent.SaveFailed)
            }
        }
    }
}
