package ir.factoryar.feature.products

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.factoryar.core.common.util.PersianFormatter
import ir.factoryar.core.domain.model.Product
import ir.factoryar.core.domain.model.ProductCategory
import ir.factoryar.core.domain.model.StockMovement
import ir.factoryar.core.domain.repository.ProductRepository
import ir.factoryar.core.domain.usecase.SaveProductUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ProductEditUiState(
    val productId: Long = 0,
    val name: String = "",
    val barcode: String = "",
    val sku: String = "",
    val categoryId: Long? = null,
    val unit: String = "عدد",
    val retailPrice: String = "",
    val wholesalePrice: String = "",
    val costPrice: String = "",
    val stockQuantity: String = "",
    val lowStockThreshold: String = "",
    val isService: Boolean = false,
    val taxPercent: String = "",
    val note: String = "",
    val categories: List<ProductCategory> = emptyList(),
    val movements: List<StockMovement> = emptyList(),
    val isSaving: Boolean = false,
    val isLoaded: Boolean = false,
    val error: String? = null,
) {
    val canSave: Boolean get() = name.isNotBlank() && !isSaving

    /** سود پیش‌بینی‌شده هر واحد: قیمت خرده − بهای تمام‌شده */
    val unitProfit: Long
        get() = PersianFormatter.parseMoney(retailPrice) - PersianFormatter.parseMoney(costPrice)

    val marginPercent: Double
        get() {
            val price = PersianFormatter.parseMoney(retailPrice)
            return if (price <= 0) 0.0 else unitProfit * 100.0 / price
        }
}

@HiltViewModel
class ProductEditViewModel @Inject constructor(
    private val repository: ProductRepository,
    private val saveProduct: SaveProductUseCase,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val existingId: Long = savedStateHandle.get<Long>("productId") ?: 0L
    /** بارکدی که کاربر اسکن کرده و کالایی برایش نبوده — پیش‌پر می‌شود */
    private val presetBarcode: String = savedStateHandle.get<String>("barcode").orEmpty()

    private val _uiState = MutableStateFlow(ProductEditUiState())
    val uiState: StateFlow<ProductEditUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.observeCategories().collect { categories ->
                _uiState.value = _uiState.value.copy(categories = categories)
            }
        }
        viewModelScope.launch {
            if (existingId > 0) {
                repository.getProduct(existingId)?.let { p ->
                    _uiState.value = _uiState.value.copy(
                        productId = p.id,
                        name = p.name,
                        barcode = p.barcode,
                        sku = p.sku,
                        categoryId = p.categoryId,
                        unit = p.unit,
                        retailPrice = p.retailPrice.takeIf { it > 0 }?.toString().orEmpty(),
                        wholesalePrice = p.wholesalePrice.takeIf { it > 0 }?.toString().orEmpty(),
                        costPrice = p.costPrice.takeIf { it > 0 }?.toString().orEmpty(),
                        stockQuantity = PersianFormatter.formatQuantity(p.stockQuantity),
                        lowStockThreshold = p.lowStockThreshold.takeIf { it > 0 }
                            ?.let { PersianFormatter.formatQuantity(it) }.orEmpty(),
                        isService = p.isService,
                        taxPercent = p.taxPercent.takeIf { it > 0 }
                            ?.let { PersianFormatter.formatQuantity(it) }.orEmpty(),
                        note = p.note,
                        isLoaded = true,
                    )
                }
                repository.observeMovements(existingId).collect { list ->
                    _uiState.value = _uiState.value.copy(movements = list)
                }
            } else {
                _uiState.value = _uiState.value.copy(
                    barcode = presetBarcode,
                    isLoaded = true,
                )
            }
        }
    }

    fun setName(v: String) { _uiState.value = _uiState.value.copy(name = v) }
    fun setBarcode(v: String) { _uiState.value = _uiState.value.copy(barcode = v.trim()) }
    fun setSku(v: String) { _uiState.value = _uiState.value.copy(sku = v) }
    fun setCategory(v: Long?) { _uiState.value = _uiState.value.copy(categoryId = v) }
    fun setUnit(v: String) { _uiState.value = _uiState.value.copy(unit = v) }
    fun setRetailPrice(v: String) { _uiState.value = _uiState.value.copy(retailPrice = v) }
    fun setWholesalePrice(v: String) { _uiState.value = _uiState.value.copy(wholesalePrice = v) }
    fun setCostPrice(v: String) { _uiState.value = _uiState.value.copy(costPrice = v) }
    fun setStockQuantity(v: String) { _uiState.value = _uiState.value.copy(stockQuantity = v) }
    fun setLowStockThreshold(v: String) { _uiState.value = _uiState.value.copy(lowStockThreshold = v) }
    fun setTaxPercent(v: String) { _uiState.value = _uiState.value.copy(taxPercent = v) }
    fun setNote(v: String) { _uiState.value = _uiState.value.copy(note = v) }
    fun setIsService(v: Boolean) { _uiState.value = _uiState.value.copy(isService = v) }

    fun addCategory(name: String) {
        viewModelScope.launch {
            if (name.isBlank()) return@launch
            val id = repository.saveCategory(ProductCategory(name = name.trim()))
            _uiState.value = _uiState.value.copy(categoryId = id)
        }
    }

    fun save(onSaved: (Long) -> Unit) {
        val s = _uiState.value
        if (!s.canSave) return
        _uiState.value = s.copy(isSaving = true, error = null)
        viewModelScope.launch {
            runCatching {
                val existing = if (s.productId > 0) repository.getProduct(s.productId) else null
                saveProduct(
                    Product(
                        id = s.productId,
                        name = s.name.trim(),
                        barcode = s.barcode.trim(),
                        sku = s.sku.trim(),
                        categoryId = s.categoryId,
                        unit = s.unit.ifBlank { "عدد" },
                        retailPrice = PersianFormatter.parseMoney(s.retailPrice),
                        wholesalePrice = PersianFormatter.parseMoney(s.wholesalePrice),
                        costPrice = PersianFormatter.parseMoney(s.costPrice),
                        stockQuantity = PersianFormatter.parseDouble(s.stockQuantity),
                        lowStockThreshold = PersianFormatter.parseDouble(s.lowStockThreshold),
                        isService = s.isService,
                        taxPercent = PersianFormatter.parseDouble(s.taxPercent).coerceIn(0.0, 100.0),
                        note = s.note.trim(),
                        active = true,
                        createdAt = existing?.createdAt ?: 0,
                    ),
                )
            }.onSuccess { id ->
                _uiState.value = _uiState.value.copy(isSaving = false)
                onSaved(id)
            }.onFailure { t ->
                _uiState.value = _uiState.value.copy(isSaving = false, error = t.message ?: "خطا در ذخیره کالا")
            }
        }
    }

    /** اصلاح دستی موجودی از صفحه ویرایش */
    fun adjustStock(delta: Double, note: String) {
        val id = _uiState.value.productId
        if (id <= 0 || delta == 0.0) return
        viewModelScope.launch {
            repository.adjustStock(id, delta, note = note)
            repository.getProduct(id)?.let { p ->
                _uiState.value = _uiState.value.copy(
                    stockQuantity = PersianFormatter.formatQuantity(p.stockQuantity),
                )
            }
        }
    }
}
