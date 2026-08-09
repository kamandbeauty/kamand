package ir.factoryar.feature.invoices

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.domain.model.Customer
import ir.factoryar.core.domain.model.Invoice
import ir.factoryar.core.domain.model.InvoiceItem
import ir.factoryar.core.domain.model.InvoiceTotals
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.model.InvoiceWithDetails
import ir.factoryar.core.domain.model.InvoiceCalculator
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.domain.model.Product
import ir.factoryar.core.domain.repository.ProductRepository
import ir.factoryar.core.domain.usecase.FindProductByBarcodeUseCase
import ir.factoryar.core.domain.repository.CustomerRepository
import ir.factoryar.core.domain.repository.InvoiceRepository
import ir.factoryar.core.domain.repository.SettingsRepository
import ir.factoryar.core.domain.usecase.GetInvoiceUseCase
import ir.factoryar.core.domain.usecase.SaveInvoiceUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/** آیتم قابل ویرایش در فرم (فیلدهای متنی برای ورودی روان) */
data class EditableItem(
    val key: String = UUID.randomUUID().toString(),
    val title: String = "",
    val quantity: String = "۱",
    val unitPrice: String = "",
    val discountPercent: String = "",
    val taxPercent: String = "",
    /** اگر از انبار انتخاب شده باشد: شناسه کالا (مبنای کسر خودکار موجودی) */
    val productId: Long? = null,
    /** بهای تمام‌شده واحد (snapshot از انبار) */
    val costPrice: Long = 0,
    /** واحد شمارش برای نمایش */
    val unit: String = "",
    /** موجودی فعلی انبار برای هشدار کمبود در فرم */
    val availableStock: Double? = null,
) {
    /** آیا مقدار درخواستی از موجودی انبار بیشتر است؟ */
    val exceedsStock: Boolean
        get() {
            val stock = availableStock ?: return false
            return PersianFormatter.parseDouble(quantity) > stock
        }

    fun toDomain(invoiceId: Long, sortOrder: Int, defaultTax: Double): InvoiceItem {
        val tax = PersianFormatter.parseDouble(taxPercent).let { if (taxPercent.isBlank()) defaultTax else it }
        return InvoiceItem(
            invoiceId = invoiceId,
            title = title.trim(),
            quantity = PersianFormatter.parseDouble(quantity).let { if (it <= 0) 1.0 else it },
            unitPrice = PersianFormatter.parseMoney(unitPrice),
            discountPercent = PersianFormatter.parseDouble(discountPercent).coerceIn(0.0, 100.0),
            taxPercent = tax.coerceIn(0.0, 100.0),
            sortOrder = sortOrder,
            productId = productId,
            costPrice = costPrice,
        )
    }

    companion object {
        /** ساخت سطر فاکتور از روی یک کالای انبار */
        fun fromProduct(product: Product, wholesale: Boolean, quantity: Double = 1.0): EditableItem = EditableItem(
            title = product.name,
            quantity = PersianFormatter.formatQuantity(quantity),
            unitPrice = product.priceFor(wholesale).toString(),
            taxPercent = if (product.taxPercent > 0) PersianFormatter.formatQuantity(product.taxPercent) else "",
            productId = product.id,
            costPrice = product.costPrice,
            unit = product.unit,
            availableStock = if (product.isService) null else product.stockQuantity,
        )
    }
}

data class InvoiceEditUiState(
    val invoiceId: Long = 0,
    val type: InvoiceType = InvoiceType.SALE,
    val number: String = "",
    val issueDate: Long = DateUtils.now(),
    val dueDate: Long? = null,
    val customerId: Long? = null,
    val customerName: String = "",
    val customers: List<Customer> = emptyList(),
    val items: List<EditableItem> = emptyList(),
    val status: PaymentStatus = PaymentStatus.UNPAID,
    val paidAmountText: String = "",
    val globalDiscountText: String = "",
    val note: String = "",
    val terms: String = "",
    val signaturePath: String? = null,
    val defaultTax: Double = 10.0,
    val isSaving: Boolean = false,
    val savedInvoiceId: Long? = null,
    val isLoaded: Boolean = false,
    /** کالاهای انبار برای انتخاب سریع */
    val products: List<Product> = emptyList(),
    /** استفاده از قیمت عمده به‌جای خرده برای این فاکتور */
    val useWholesalePrice: Boolean = false,
    /** پیام موقت (مثلاً کالای بارکد پیدا نشد) */
    val message: String? = null,
) {
    fun domainItems(): List<InvoiceItem> =
        items.mapIndexed { index, e -> e.toDomain(invoiceId, index, defaultTax) }
            .filter { it.title.isNotBlank() }

    val totals: InvoiceTotals
        get() = InvoiceCalculator.calculate(domainItems(), PersianFormatter.parseMoney(globalDiscountText))

    /** سود ناخالص تخمینی این فاکتور (فقط برای اقلام دارای بهای تمام‌شده) */
    val estimatedProfit: Long
        get() = domainItems().filter { it.costPrice > 0 }.sumOf { it.lineProfit }

    val hasCostData: Boolean get() = domainItems().any { it.costPrice > 0 }

    /** آیا سطری بیش از موجودی انبار دارد؟ */
    val hasStockWarning: Boolean get() = type == InvoiceType.SALE && items.any { it.exceedsStock }
}

@HiltViewModel
class InvoiceEditViewModel @Inject constructor(
    private val getInvoice: GetInvoiceUseCase,
    private val saveInvoice: SaveInvoiceUseCase,
    private val invoiceRepository: InvoiceRepository,
    private val customerRepository: CustomerRepository,
    private val productRepository: ProductRepository,
    private val findProductByBarcode: FindProductByBarcodeUseCase,
    settingsRepository: SettingsRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val existingId: Long = savedStateHandle.get<Long>("invoiceId") ?: 0L
    private val requestedType: InvoiceType =
        InvoiceType.fromName(savedStateHandle.get<String>("type"))

    private val _uiState = MutableStateFlow(InvoiceEditUiState(type = requestedType))
    val uiState: StateFlow<InvoiceEditUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            customerRepository.observeCustomers().collect { list ->
                _uiState.value = _uiState.value.copy(customers = list.map { it.customer })
            }
        }
        viewModelScope.launch {
            productRepository.observeProducts().collect { list ->
                _uiState.value = _uiState.value.copy(products = list.map { it.product })
            }
        }
        viewModelScope.launch {
            val settings = settingsRepository.settings.first()
            val defaultTax = settings.defaultTaxPercent
            val terms = settings.defaultTerms
            _uiState.value = _uiState.value.copy(defaultTax = defaultTax, terms = terms)

            if (existingId > 0) {
                getInvoice(existingId).first()?.let { d ->
                    _uiState.value = _uiState.value.copy(
                        invoiceId = d.invoice.id,
                        type = d.invoice.type,
                        number = d.invoice.number,
                        issueDate = d.invoice.issueDate,
                        dueDate = d.invoice.dueDate,
                        customerId = d.invoice.customerId,
                        customerName = d.customer?.name ?: "",
                        items = d.items.map {
                            EditableItem(
                                title = it.title,
                                quantity = PersianFormatter.formatQuantity(it.quantity),
                                unitPrice = it.unitPrice.toString(),
                                discountPercent = if (it.discountPercent > 0) PersianFormatter.formatQuantity(it.discountPercent) else "",
                                taxPercent = PersianFormatter.formatQuantity(it.taxPercent),
                                productId = it.productId,
                                costPrice = it.costPrice,
                            )
                        },
                        status = d.invoice.status,
                        paidAmountText = if (d.invoice.paidAmount > 0) d.invoice.paidAmount.toString() else "",
                        globalDiscountText = if (d.invoice.globalDiscount > 0) d.invoice.globalDiscount.toString() else "",
                        note = d.invoice.note,
                        terms = d.invoice.terms.ifBlank { terms },
                        signaturePath = d.invoice.signaturePath,
                        isLoaded = true,
                    )
                }
            } else {
                _uiState.value = _uiState.value.copy(
                    number = "یک شماره خودکار: " + invoiceRepository.previewNextNumber(requestedType),
                    items = listOf(EditableItem()),
                    isLoaded = true,
                )
            }
        }
    }

    // ---------------- تغییرات فرم ----------------

    fun setIssueDate(millis: Long) { _uiState.value = _uiState.value.copy(issueDate = millis) }
    fun setDueDate(millis: Long?) { _uiState.value = _uiState.value.copy(dueDate = millis) }
    fun setNote(note: String) { _uiState.value = _uiState.value.copy(note = note) }
    fun setTerms(terms: String) { _uiState.value = _uiState.value.copy(terms = terms) }
    fun setGlobalDiscount(text: String) { _uiState.value = _uiState.value.copy(globalDiscountText = text) }

    fun setStatus(status: PaymentStatus) {
        val state = _uiState.value
        val paidText = when (status) {
            PaymentStatus.PAID -> state.totals.grandTotal.toString()
            PaymentStatus.UNPAID -> ""
            PaymentStatus.PARTIAL -> state.paidAmountText
        }
        _uiState.value = state.copy(status = status, paidAmountText = paidText)
    }

    fun setPaidAmount(text: String) { _uiState.value = _uiState.value.copy(paidAmountText = text) }

    fun selectCustomer(customer: Customer?) {
        _uiState.value = _uiState.value.copy(customerId = customer?.id, customerName = customer?.name ?: "")
    }

    fun quickCreateCustomer(name: String, phone: String, onCreated: () -> Unit = {}) {
        viewModelScope.launch {
            val id = customerRepository.saveCustomer(Customer(name = name.trim(), phone = phone.trim()))
            _uiState.value = _uiState.value.copy(customerId = id, customerName = name.trim())
            onCreated()
        }
    }

    // ---------------- آیتم‌ها ----------------

    fun addItem() {
        _uiState.value = _uiState.value.copy(items = _uiState.value.items + EditableItem())
    }

    fun updateItem(key: String, transform: (EditableItem) -> EditableItem) {
        _uiState.value = _uiState.value.copy(
            items = _uiState.value.items.map { if (it.key == key) transform(it) else it },
        )
    }

    fun removeItem(key: String) {
        _uiState.value = _uiState.value.copy(items = _uiState.value.items.filterNot { it.key == key })
    }

    fun setSignaturePath(path: String?) {
        _uiState.value = _uiState.value.copy(signaturePath = path)
    }

    fun setUseWholesalePrice(value: Boolean) {
        _uiState.value = _uiState.value.copy(useWholesalePrice = value)
    }

    fun consumeMessage() { _uiState.value = _uiState.value.copy(message = null) }

    /** افزودن کالای انبار به فاکتور (از لیست یا اسکن بارکد) */
    fun addProduct(product: Product) {
        val state = _uiState.value
        val existing = state.items.firstOrNull { it.productId == product.id }
        if (existing != null) {
            // اگر کالا قبلاً در فاکتور بود، فقط تعداد را یکی زیاد می‌کنیم
            val newQty = PersianFormatter.parseDouble(existing.quantity) + 1
            updateItem(existing.key) { it.copy(quantity = PersianFormatter.formatQuantity(newQty)) }
        } else {
            val newItem = EditableItem.fromProduct(product, state.useWholesalePrice)
            // اگر سطر خالی اول وجود دارد، جایش را می‌گیریم
            val emptyRow = state.items.firstOrNull { it.title.isBlank() && it.unitPrice.isBlank() }
            val items = if (emptyRow != null) {
                state.items.map { if (it.key == emptyRow.key) newItem else it }
            } else {
                state.items + newItem
            }
            _uiState.value = state.copy(items = items)
        }
    }

    /**
     * اسکن بارکد در فرم فاکتور:
     * اگر کالا پیدا شد به فاکتور اضافه می‌شود، در غیر این صورت پیام «یافت نشد» می‌دهد.
     */
    fun onBarcodeScanned(barcode: String) {
        viewModelScope.launch {
            val product = findProductByBarcode(barcode)
            if (product != null) {
                addProduct(product)
                _uiState.value = _uiState.value.copy(message = "«${product.name}» به فاکتور اضافه شد")
            } else {
                _uiState.value = _uiState.value.copy(
                    message = "کالایی با بارکد ${barcode} در انبار یافت نشد",
                )
            }
        }
    }

    // ---------------- ذخیره ----------------

    fun save(onSaved: (Long) -> Unit = {}) {
        val state = _uiState.value
        val items = state.domainItems()
        if (items.isEmpty()) return
        if (state.isSaving) return
        _uiState.value = state.copy(isSaving = true)
        viewModelScope.launch {
            val status = when {
                state.status == PaymentStatus.PAID -> PaymentStatus.PAID
                PersianFormatter.parseMoney(state.paidAmountText) > 0 -> state.status
                else -> PaymentStatus.UNPAID
            }
            val invoice = Invoice(
                id = state.invoiceId,
                number = if (state.invoiceId > 0) state.number else "",
                type = state.type,
                customerId = state.customerId,
                issueDate = state.issueDate,
                dueDate = state.dueDate,
                status = status,
                paidAmount = PersianFormatter.parseMoney(state.paidAmountText),
                globalDiscount = PersianFormatter.parseMoney(state.globalDiscountText),
                note = state.note.trim(),
                terms = state.terms.trim(),
                signaturePath = state.signaturePath,
            )
            runCatching { saveInvoice(InvoiceWithDetails(invoice, items)) }
                .onSuccess { id ->
                    _uiState.value = _uiState.value.copy(isSaving = false, savedInvoiceId = id)
                    onSaved(id)
                }
                .onFailure { _uiState.value = _uiState.value.copy(isSaving = false) }
        }
    }
}
