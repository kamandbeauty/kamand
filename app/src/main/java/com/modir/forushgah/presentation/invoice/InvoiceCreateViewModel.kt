package com.modir.forushgah.presentation.invoice

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.isNegative
import com.modir.forushgah.core.common.isPositive
import com.modir.forushgah.core.date.JalaliDateFormatter
import com.modir.forushgah.data.repository.CustomerRepository
import com.modir.forushgah.data.repository.NewOrder
import com.modir.forushgah.data.repository.NewOrderItem
import com.modir.forushgah.data.repository.OrderRepository
import com.modir.forushgah.data.repository.ProductRepository
import com.modir.forushgah.data.repository.ReferenceDataRepository
import com.modir.forushgah.data.repository.StoreProfileRepository
import com.modir.forushgah.data.repository.SupplierRepository
import com.modir.forushgah.domain.model.InsufficientStockException
import com.modir.forushgah.domain.model.OrderKind
import com.modir.forushgah.domain.model.PaymentMethod
import com.modir.forushgah.domain.model.Product
import com.modir.forushgah.domain.model.SalesChannel
import com.modir.forushgah.domain.model.ShippingPaymentType
import com.modir.forushgah.domain.model.StoreProfile
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/** One editable line of the invoice (Rubi item: title / مقدار / قیمت واحد). */
data class InvoiceLineUi(
    val id: Long,
    val productId: Long? = null,
    val title: String,
    val quantity: String = "1",
    val unit: String = "عدد",
    val unitPrice: String = "",
) {
    val quantityInt: Int get() = quantity.toIntOrNull() ?: 0
    val unitPriceMoney: Money get() = Money(unitPrice.toLongOrNull() ?: 0)
    /** Rubi item.totalPrice = quantity × unitPrice (line discount is order-level). */
    val lineTotal: Money get() = unitPriceMoney * quantityInt
}

/**
 * Rubi invoice-create state. Field order and calculations follow the
 * reference app exactly:
 * totalAmount = (subtotal − discount + shippingFee).clamp(0, ∞)
 */
data class InvoiceCreateUiState(
    val isLoading: Boolean = true,
    val customerName: String = "",
    val customerPhone: String = "",
    val number: String = "",
    val date: String = "", // Jalali yyyy/MM/dd (Rubi «تاریخ شمسی»)
    val isPurchase: Boolean = false,
    val cashPayment: Boolean = true,
    val lines: List<InvoiceLineUi> = emptyList(),
    val discount: String = "",
    val shippingFee: String = "",
    val notes: String = "با تشکر از خرید شما",
    val selectorQuery: String = "",
    val selectorProducts: List<Product> = emptyList(),
    val store: StoreProfile? = null,
    val paymentMethods: List<PaymentMethod> = emptyList(),
    val salesChannels: List<SalesChannel> = emptyList(),
    val editingOrderId: Long? = null,
    val errors: List<String> = emptyList(),
    val isSaving: Boolean = false,
    val savedOrderId: Long? = null,
) {
    val isEditMode: Boolean get() = editingOrderId != null
    val counterpartyLabel: String get() = if (isPurchase) "تأمین‌کننده" else "مشتری"

    val subtotal: Money get() = Money.sum(lines.map { it.lineTotal })
    val discountMoney: Money get() = Money(discount.toLongOrNull() ?: 0)
    val shippingMoney: Money get() = Money(shippingFee.toLongOrNull() ?: 0)

    /** Rubi: (_subtotal - _discountAmount + _shippingFee).clamp(0, ∞) */
    val total: Money get() = (subtotal - discountMoney + shippingMoney).coerceAtLeastZero()
}

/**
 * Rubi invoice creation (Phase 3.1) — one screen, fast flow:
 * counterparty → items (product-selection popup) → totals → save. All
 * calculations live in the domain/model; persistence goes through the
 * transactional [OrderRepository] (spec §9/§14).
 */
@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class InvoiceCreateViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val customerRepository: CustomerRepository,
    private val supplierRepository: SupplierRepository,
    private val productRepository: ProductRepository,
    private val storeProfileRepository: StoreProfileRepository,
    private val referenceDataRepository: ReferenceDataRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val editingOrderId: Long? = savedStateHandle.get<Long>("orderId")

    private val selectorQuery = MutableStateFlow("")
    private val selectorProducts = selectorQuery.flatMapLatest { q ->
        if (q.isNotBlank()) productRepository.observeSearch(q) else productRepository.observeActiveProducts()
    }

    private val _state = MutableStateFlow(InvoiceCreateUiState(editingOrderId = editingOrderId))
    val uiState: StateFlow<InvoiceCreateUiState> = combine(
        _state,
        selectorProducts,
        storeProfileRepository.observeStore(),
        referenceDataRepository.observePaymentMethods(),
        referenceDataRepository.observeSalesChannels(),
    ) { base, products, store, paymentMethods, salesChannels ->
        base.copy(
            isLoading = false,
            selectorProducts = products,
            store = store,
            paymentMethods = paymentMethods,
            salesChannels = salesChannels,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), InvoiceCreateUiState())

    init {
        viewModelScope.launch {
            if (editingOrderId != null) {
                orderRepository.loadEditable(editingOrderId)?.let { load ->
                    val customer = load.customerId?.let { customerRepository.getById(it) }
                    val supplier = load.supplierId?.let { supplierRepository.getById(it) }
                    _state.update {
                        it.copy(
                            customerName = customer?.name ?: supplier?.name.orEmpty(),
                            customerPhone = customer?.mobile ?: supplier?.phone.orEmpty(),
                            number = load.orderNumber.orEmpty(),
                            date = JalaliDateFormatter.formatJalali(load.orderDate, persianDigits = false),
                            isPurchase = load.kind == OrderKind.PURCHASE,
                            cashPayment = load.cashPayment,
                            lines = load.items.map {
                                InvoiceLineUi(
                                    id = System.nanoTime(),
                                    productId = it.productId,
                                    title = it.title.ifEmpty { "کالا" },
                                    quantity = it.quantity.toString(),
                                    unit = it.unit,
                                    unitPrice = it.unitSellingPrice.amountInToman.toString(),
                                )
                            },
                            discount = load.orderDiscount.amountInToman.takeIf { it != 0L }?.toString().orEmpty(),
                            shippingFee = load.shippingChargedToCustomer.amountInToman.takeIf { it != 0L }?.toString().orEmpty(),
                            notes = load.notes.orEmpty().ifEmpty { "با تشکر از خرید شما" },
                        )
                    }
                    return@launch
                }
            }
            // Rubi prefill: next sequential number + today's Jalali date.
            _state.update {
                it.copy(
                    number = it.number.ifEmpty { orderRepository.nextNumberPreview() },
                    date = it.date.ifEmpty { JalaliDateFormatter.todayJalali() },
                )
            }
        }
    }

    // ---------- fields (Rubi create card) ----------

    fun onCustomerNameChange(v: String) = _state.update { it.copy(customerName = v) }
    fun onCustomerPhoneChange(v: String) = _state.update { it.copy(customerPhone = v.filter { c -> c.isDigit() || c == '+' }) }
    fun onNumberChange(v: String) = _state.update { it.copy(number = v.filter { c -> c.isDigit() }) }
    fun onDateChange(v: String) = _state.update { it.copy(date = v) }
    fun onKindChange(purchase: Boolean) = _state.update { it.copy(isPurchase = purchase) }
    fun onPaymentTypeChange(cash: Boolean) = _state.update { it.copy(cashPayment = cash) }
    fun onDiscountChange(v: String) = _state.update { it.copy(discount = v.filter { c -> c.isDigit() }) }
    fun onShippingFeeChange(v: String) = _state.update { it.copy(shippingFee = v.filter { c -> c.isDigit() }) }
    fun onNotesChange(v: String) = _state.update { it.copy(notes = v) }

    // ---------- product selection popup (spec §4) ----------

    fun onSelectorQueryChange(v: String) {
        selectorQuery.value = v
    }

    /** Selects a real product from the DB — fills the line with its name,
     * unit and price (sell price for sales, buy price for purchases). */
    fun onProductSelected(productId: Long, quantity: Int) {
        val s = _state.value
        val product = s.selectorProducts.firstOrNull { it.id == productId } ?: return
        onSelectorQueryChange("")
        _state.update { st ->
            val qty = if (st.isPurchase) quantity else quantity.coerceAtMost(product.stockQuantity)
            val existing = st.lines.indexOfFirst { it.productId == productId }
            val newLines = if (existing >= 0) {
                val line = st.lines[existing]
                val newQty = if (st.isPurchase) line.quantityInt + qty else (line.quantityInt + qty).coerceAtMost(product.stockQuantity)
                st.lines.toMutableList().apply { this[existing] = line.copy(quantity = newQty.toString()) }
            } else {
                st.lines + InvoiceLineUi(
                    id = System.nanoTime(),
                    productId = product.id,
                    title = product.name,
                    quantity = qty.toString(),
                    unit = product.unit,
                    unitPrice = (if (st.isPurchase) product.purchasePrice else product.sellingPrice).amountInToman.toString(),
                )
            }
            st.copy(lines = newLines, errors = emptyList())
        }
    }

    /** Rubi «افزودن آیتم» — a free manual line (no product, no inventory). */
    fun onFreeItemAdded() {
        _state.update {
            it.copy(lines = it.lines + InvoiceLineUi(id = System.nanoTime(), title = "آیتم جدید", unitPrice = "100000"))
        }
    }

    fun onLineTitleChange(lineId: Long, v: String) =
        _state.update { it.copy(lines = it.lines.map { l -> if (l.id == lineId) l.copy(title = v) else l }) }

    fun onLineQuantityChange(lineId: Long, v: String) =
        _state.update { it.copy(lines = it.lines.map { l -> if (l.id == lineId) l.copy(quantity = v.filter { c -> c.isDigit() }) else l }) }

    fun onLinePriceChange(lineId: Long, v: String) =
        _state.update { it.copy(lines = it.lines.map { l -> if (l.id == lineId) l.copy(unitPrice = v.filter { c -> c.isDigit() }) else l }) }

    fun onLineRemoved(lineId: Long) = _state.update { it.copy(lines = it.lines.filterNot { l -> l.id == lineId }) }

    // ---------- product creation from the invoice (spec §5) ----------

    fun createProductFromInvoice(
        name: String,
        code: String,
        unit: String,
        sellPrice: String,
        buyPrice: String,
        stock: String,
        notes: String,
    ): String? {
        val trimmedName = name.trim()
        if (trimmedName.isEmpty()) return "نام محصول را وارد کنید"
        val now = System.currentTimeMillis()
        val product = Product(
            name = trimmedName,
            sku = code.trim().ifEmpty { "P-${System.currentTimeMillis() % 1000000}" },
            unit = unit.trim().ifEmpty { "عدد" },
            sellingPrice = Money(sellPrice.toLongOrNull() ?: 0),
            purchasePrice = Money(buyPrice.toLongOrNull() ?: 0),
            stockQuantity = stock.toIntOrNull() ?: 0,
            notes = notes.trim().ifEmpty { null },
            createdAt = now,
            updatedAt = now,
        )
        viewModelScope.launch {
            try {
                productRepository.create(product)
            } catch (e: Exception) {
                // sku unique constraint — retry once with a generated code
                try {
                    productRepository.create(product.copy(sku = "P-${System.currentTimeMillis() % 1000000}"))
                } catch (e2: Exception) {
                    _state.update { it.copy(errors = listOf("ثبت محصول ناموفق بود: ${e2.message}")) }
                }
            }
        }
        return null
    }

    // ---------- save (Rubi _saveInvoice → transactional OrderRepository) ----------

    fun save() {
        val s = _state.value
        // Rubi: keep only lines that have a title or a price.
        val cleanLines = s.lines.filter { it.title.trim().isNotEmpty() || it.unitPriceMoney.isPositive }
        if (cleanLines.isEmpty()) {
            _state.update { it.copy(errors = listOf("حداقل یک قلم کالا اضافه کنید")) }
            return
        }
        for (line in cleanLines) {
            if (line.quantityInt <= 0) {
                _state.update { it.copy(errors = listOf("مقدار همهٔ اقلام باید بیشتر از صفر باشد")) }
                return
            }
            // Stock validation for sales lines (spec: respect real inventory).
            if (!s.isPurchase && line.productId != null) {
                val product = s.selectorProducts.firstOrNull { it.id == line.productId }
                if (product != null && line.quantityInt > product.stockQuantity) {
                    _state.update {
                        it.copy(errors = listOf("موجودی «${product.name}» کافی نیست (فقط ${product.stockQuantity} واحد)"))
                    }
                    return
                }
            }
            if (line.unitPriceMoney.isNegative) {
                _state.update { it.copy(errors = listOf("قیمت واحد نمی‌تواند منفی باشد")) }
                return
            }
        }
        if (s.discountMoney > s.subtotal) {
            _state.update { it.copy(errors = listOf("تخفیف نمی‌تواند از جمع اقلام بیشتر باشد")) }
            return
        }

        viewModelScope.launch {
            _state.update { it.copy(isSaving = true, errors = emptyList()) }
            try {
                val now = parseJalaliOrNow(s.date)
                val items = cleanLines.map { line ->
                    NewOrderItem(
                        productId = line.productId,
                        quantity = line.quantityInt,
                        unitSellingPrice = line.unitPriceMoney,
                        unitPurchasePrice = line.unitPriceMoney,
                        title = line.title.trim(),
                        unit = line.unit,
                    )
                }
                val counterpartyId: Long = if (s.isPurchase) {
                    val name = s.customerName.trim().ifEmpty { "تأمین‌کننده عمومی" }
                    supplierRepository.getOrCreateByName(name, s.customerPhone.trim().ifEmpty { null }, now).id
                } else {
                    val name = s.customerName.trim().ifEmpty { "مشتری عمومی" }
                    customerRepository.getOrCreateByName(name, s.customerPhone.trim().ifEmpty { null }, now).id
                }
                val draft = NewOrder(
                    customerId = if (s.isPurchase) null else counterpartyId,
                    supplierId = if (s.isPurchase) counterpartyId else null,
                    kind = if (s.isPurchase) OrderKind.PURCHASE else OrderKind.SALES,
                    items = items,
                    orderDiscount = s.discountMoney,
                    shippingChargedToCustomer = s.shippingMoney,
                    shippingPaymentType =
                        if (s.shippingMoney.isPositive) ShippingPaymentType.CUSTOMER_PREPAID
                        else ShippingPaymentType.SELLER_PAID,
                    cashPayment = s.cashPayment,
                    notes = s.notes.trim().ifEmpty { null },
                    orderNumber = s.number.trim().ifEmpty { null },
                    orderDate = now,
                )
                val orderId = if (s.isEditMode) {
                    orderRepository.replaceOrder(s.editingOrderId!!, draft).id
                } else {
                    orderRepository.createOrder(draft).id
                }
                _state.update { it.copy(isSaving = false, savedOrderId = orderId) }
            } catch (e: InsufficientStockException) {
                _state.update { it.copy(isSaving = false, errors = listOf("موجودی یکی از اقلام کافی نیست؛ فاکتور ثبت نشد")) }
            } catch (e: Exception) {
                _state.update { it.copy(isSaving = false, errors = listOf(e.message ?: "ثبت فاکتور با خطا مواجه شد")) }
            }
        }
    }

    /** Rubi dates are Jalali `yyyy/MM/dd`; parse to epoch millis (day start),
     * falling back to now for anything unparsable. */
    private fun parseJalaliOrNow(dateText: String): Long =
        JalaliDateFormatter.parseJalaliText(dateText) ?: System.currentTimeMillis()
}
