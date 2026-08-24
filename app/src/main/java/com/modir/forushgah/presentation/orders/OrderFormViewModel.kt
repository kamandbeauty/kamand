package com.modir.forushgah.presentation.orders

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.repository.CustomerRepository
import com.modir.forushgah.data.repository.OrderRepository
import com.modir.forushgah.data.repository.ProductRepository
import com.modir.forushgah.data.repository.ReferenceDataRepository
import com.modir.forushgah.data.repository.NewOrder
import com.modir.forushgah.data.repository.NewOrderItem
import com.modir.forushgah.domain.model.Customer
import com.modir.forushgah.domain.model.InsufficientStockException
import com.modir.forushgah.domain.model.PaymentMethod
import com.modir.forushgah.domain.model.Product
import com.modir.forushgah.domain.model.SalesChannel
import com.modir.forushgah.domain.model.ShippingPaymentType
import com.modir.forushgah.domain.model.ShippingProvider
import com.modir.forushgah.domain.usecase.order.OrderItemDraft
import com.modir.forushgah.domain.usecase.order.OrderValidationDraft
import com.modir.forushgah.domain.usecase.order.ValidateOrderUseCase
import com.modir.forushgah.domain.validation.ValidationResult
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/** One product line in the create-order form (spec §5). */
data class OrderLineUi(
    val productId: Long,
    val name: String,
    val availableStock: Int,
    val quantity: Int = 1,
    val unitPrice: String = "", // digit string, Tomans
    val itemDiscount: Money = Money.ZERO,
    val unitPurchasePrice: Money,
) {
    val unitPriceMoney: Money get() = Money(unitPrice.toLongOrNull() ?: 0)
    val lineSubtotal: Money get() = unitPriceMoney * quantity - itemDiscount
}

/** Simple form fields that change on every keystroke (kept out of the
 * combined flow so typing never re-collects repository data). */
private data class OrderFormFields(
    val orderDiscount: Money = Money.ZERO,
    val salesChannelId: Long? = null,
    val paymentMethodId: Long? = null,
    val shippingProviderId: Long? = null,
    val shippingPaymentType: ShippingPaymentType = ShippingPaymentType.SELLER_PAID,
    val shippingCharged: String = "",
    val actualShippingCost: String = "",
    val packagingCost: String = "",
    val notes: String = "",
    val errors: List<String> = emptyList(),
    val isSaving: Boolean = false,
    val isSaved: Boolean = false,
)

data class OrderFormUiState(
    val isLoading: Boolean = true,
    val selectedCustomer: Customer? = null,
    val customers: List<Customer> = emptyList(),
    val customerQuery: String = "",
    val products: List<Product> = emptyList(),
    val productQuery: String = "",
    val lines: List<OrderLineUi> = emptyList(),
    val orderDiscount: Money = Money.ZERO,
    val salesChannels: List<SalesChannel> = emptyList(),
    val salesChannelId: Long? = null,
    val paymentMethods: List<PaymentMethod> = emptyList(),
    val paymentMethodId: Long? = null,
    val shippingProviders: List<ShippingProvider> = emptyList(),
    val shippingProviderId: Long? = null,
    val shippingPaymentType: ShippingPaymentType = ShippingPaymentType.SELLER_PAID,
    val shippingCharged: String = "",
    val actualShippingCost: String = "",
    val packagingCost: String = "",
    val notes: String = "",
    val errors: List<String> = emptyList(),
    val isSaving: Boolean = false,
    val isSaved: Boolean = false,
) {
    val productSubtotal: Money get() = Money.sum(lines.map { it.lineSubtotal })
    val shippingChargedMoney: Money get() = Money(shippingCharged.toLongOrNull() ?: 0)
    val total: Money
        get() = (productSubtotal - orderDiscount) +
            if (shippingPaymentType == ShippingPaymentType.CUSTOMER_PREPAID) shippingChargedMoney else Money.ZERO
}

/**
 * Single-screen, fast-flow order creation (spec §3): customer → products →
 * quantities → discounts → shipping → payment → review → save. No separate
 * screens per step; all selection happens in dialogs.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class OrderFormViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val customerRepository: CustomerRepository,
    private val productRepository: ProductRepository,
    private val referenceDataRepository: ReferenceDataRepository,
    private val validateOrder: ValidateOrderUseCase,
) : ViewModel() {

    private val customerQuery = MutableStateFlow("")
    private val productQuery = MutableStateFlow("")
    private val selectedCustomer = MutableStateFlow<Customer?>(null)
    private val lines = MutableStateFlow<List<OrderLineUi>>(emptyList())
    private val fields = MutableStateFlow(OrderFormFields())

    private val customersFlow = customerQuery.flatMapLatest { q ->
        if (q.isNotBlank()) customerRepository.observeSearch(q) else customerRepository.observeAll()
    }
    private val productsFlow = productQuery.flatMapLatest { q ->
        if (q.isNotBlank()) productRepository.observeSearch(q) else productRepository.observeActiveProducts()
    }
    private val referenceFlow = combine(
        referenceDataRepository.observeSalesChannels(),
        referenceDataRepository.observeShippingProviders(),
        referenceDataRepository.observePaymentMethods(),
    ) { channels, providers, methods -> Triple(channels, providers, methods) }

    /** Joined "main" read-model of the form (no I/O inside). */
    private data class MainParts(
        val customerQuery: String,
        val productQuery: String,
        val customers: List<Customer>,
        val products: List<Product>,
        val selectedCustomer: Customer?,
        val lines: List<OrderLineUi>,
    )

    private val queriesFlow = combine(customerQuery, productQuery) { cq, pq -> cq to pq }

    private val mainFlow = combine(queriesFlow, customersFlow, productsFlow, selectedCustomer, lines) {
        queries, customers, products, customer, lineList ->
        MainParts(queries.first, queries.second, customers, products, customer, lineList)
    }

    val uiState: StateFlow<OrderFormUiState> = combine(mainFlow, referenceFlow, fields) { main, reference, f ->
        val (channels, providers, methods) = reference
        OrderFormUiState(
            isLoading = false,
            selectedCustomer = main.selectedCustomer,
            customers = main.customers,
            customerQuery = main.customerQuery,
            products = main.products,
            productQuery = main.productQuery,
            lines = main.lines,
            orderDiscount = f.orderDiscount,
            salesChannels = channels,
            salesChannelId = f.salesChannelId,
            paymentMethods = methods,
            paymentMethodId = f.paymentMethodId,
            shippingProviders = providers,
            shippingProviderId = f.shippingProviderId,
            shippingPaymentType = f.shippingPaymentType,
            shippingCharged = f.shippingCharged,
            actualShippingCost = f.actualShippingCost,
            packagingCost = f.packagingCost,
            notes = f.notes,
            errors = f.errors,
            isSaving = f.isSaving,
            isSaved = f.isSaved,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), OrderFormUiState())

    // ---- customer (spec §4) ----

    fun onCustomerQueryChange(value: String) {
        customerQuery.value = value
    }

    fun onCustomerSelected(customer: Customer) {
        selectedCustomer.value = customer
    }

    /** Inline creation without leaving the order screen (spec §9). */
    fun onQuickCreateCustomer(name: String, mobile: String?) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch {
            val id = customerRepository.quickCreate(trimmed, mobile)
            customerRepository.getById(id)?.let { selectedCustomer.value = it }
        }
    }

    // ---- product lines (spec §5) ----

    fun onProductQueryChange(value: String) {
        productQuery.value = value
    }

    /** Adds the product, or bumps quantity if it's already on the order —
     * never above available stock (spec §5: prevent overselling). */
    fun onProductAdded(product: Product) {
        lines.update { list ->
            val index = list.indexOfFirst { it.productId == product.id }
            when {
                index >= 0 -> {
                    val line = list[index]
                    if (line.quantity >= product.stockQuantity) list
                    else list.toMutableList().apply { this[index] = line.copy(quantity = line.quantity + 1) }
                }
                else -> list + OrderLineUi(
                    productId = product.id,
                    name = product.name,
                    availableStock = product.stockQuantity,
                    quantity = 1,
                    unitPrice = product.sellingPrice.amountInToman.toString(),
                    unitPurchasePrice = product.purchasePrice,
                )
            }
        }
    }

    fun onQuantityChange(productId: Long, newQuantity: Int) {
        lines.update { list ->
            when {
                newQuantity <= 0 -> list.filterNot { it.productId == productId }
                else -> list.map {
                    if (it.productId == productId) it.copy(quantity = newQuantity.coerceAtMost(it.availableStock)) else it
                }
            }
        }
    }

    fun onUnitPriceChange(productId: Long, value: String) {
        lines.update { list ->
            list.map { if (it.productId == productId) it.copy(unitPrice = value.filter { c -> c.isDigit() }) else it }
        }
    }

    fun onItemDiscount(productId: Long, discount: Money) {
        lines.update { list -> list.map { if (it.productId == productId) it.copy(itemDiscount = discount) else it } }
    }

    fun onRemoveLine(productId: Long) {
        lines.update { list -> list.filterNot { it.productId == productId } }
    }

    // ---- order-level fields (spec §7/§8/§9/§10/§11/§13) ----

    fun onOrderDiscountChange(discount: Money) {
        fields.update { it.copy(orderDiscount = discount) }
    }

    fun onSalesChannelChange(id: Long?) {
        fields.update { it.copy(salesChannelId = id) }
    }

    fun onPaymentMethodChange(id: Long?) {
        fields.update { it.copy(paymentMethodId = id) }
    }

    fun onShippingProviderChange(id: Long?) {
        fields.update { it.copy(shippingProviderId = id) }
    }

    fun onShippingPaymentTypeChange(type: ShippingPaymentType) {
        fields.update { it.copy(shippingPaymentType = type) }
    }

    fun onShippingChargedChange(value: String) {
        fields.update { it.copy(shippingCharged = value.filter { c -> c.isDigit() }) }
    }

    fun onActualShippingCostChange(value: String) {
        fields.update { it.copy(actualShippingCost = value.filter { c -> c.isDigit() }) }
    }

    fun onPackagingCostChange(value: String) {
        fields.update { it.copy(packagingCost = value.filter { c -> c.isDigit() }) }
    }

    fun onNotesChange(value: String) {
        fields.update { it.copy(notes = value) }
    }

    // ---- save (spec §19/§26: transactional, idempotent stock deduction) ----

    fun save() {
        val s = uiState.value
        val draft = OrderValidationDraft(
            customerId = s.selectedCustomer?.id,
            items = s.lines.map {
                OrderItemDraft(it.productId, it.name, it.quantity, it.unitPriceMoney, it.itemDiscount, it.availableStock)
            },
            orderDiscount = s.orderDiscount,
            shippingChargedToCustomer = s.shippingChargedMoney,
            actualShippingCost = Money(s.actualShippingCost.toLongOrNull() ?: 0),
            packagingCost = Money(s.packagingCost.toLongOrNull() ?: 0),
        )
        val result = validateOrder(draft)
        if (result is ValidationResult.Invalid) {
            fields.update { it.copy(errors = result.messages) }
            return
        }

        viewModelScope.launch {
            fields.update { it.copy(isSaving = true, errors = emptyList()) }
            try {
                val paymentMethod = s.paymentMethods.firstOrNull { it.id == s.paymentMethodId }
                orderRepository.createOrder(
                    NewOrder(
                        customerId = s.selectedCustomer!!.id,
                        items = s.lines.map {
                            NewOrderItem(it.productId, it.quantity, it.unitPriceMoney, it.unitPurchasePrice, it.itemDiscount)
                        },
                        orderDiscount = s.orderDiscount,
                        salesChannelId = s.salesChannelId,
                        paymentMethodId = s.paymentMethodId,
                        paymentMethodLabel = paymentMethod?.name ?: "نقدی",
                        shippingProviderId = s.shippingProviderId,
                        shippingPaymentType = s.shippingPaymentType,
                        // Only prepaid shipping is money the customer pays the seller
                        // (spec §12); COD is paid to the courier, seller-paid is 0.
                        shippingChargedToCustomer =
                        if (s.shippingPaymentType == ShippingPaymentType.CUSTOMER_PREPAID) s.shippingChargedMoney else Money.ZERO,
                        actualShippingCost = Money(s.actualShippingCost.toLongOrNull() ?: 0),
                        packagingCost = Money(s.packagingCost.toLongOrNull() ?: 0),
                        notes = s.notes.ifBlank { null },
                    ),
                )
                fields.update { it.copy(isSaving = false, isSaved = true) }
            } catch (e: InsufficientStockException) {
                fields.update {
                    it.copy(isSaving = false, errors = listOf("موجودی یکی از کالاهای سفارش کافی نیست؛ سفارش ثبت نشد"))
                }
            } catch (e: Exception) {
                fields.update { it.copy(isSaving = false, errors = listOf(e.message ?: "ثبت سفارش با خطا مواجه شد")) }
            }
        }
    }
}
