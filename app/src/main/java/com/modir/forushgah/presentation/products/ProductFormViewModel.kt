package com.modir.forushgah.presentation.products

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.repository.CategoryRepository
import com.modir.forushgah.data.repository.ProductRepository
import com.modir.forushgah.domain.model.Category
import com.modir.forushgah.domain.model.Product
import com.modir.forushgah.domain.usecase.product.ProductDraft
import com.modir.forushgah.domain.usecase.product.ValidateProductUseCase
import com.modir.forushgah.domain.validation.ValidationResult
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ProductFormState(
    val productId: Long? = null,
    val name: String = "",
    val sku: String = "",
    val barcode: String = "",
    val categoryId: Long? = null,
    val supplierId: Long? = null,
    val sellingPrice: String = "",
    val purchasePrice: String = "",
    val packagingCost: String = "",
    val stockQuantity: String = "",
    val minimumStock: String = "",
    val notes: String = "",
    val categories: List<Category> = emptyList(),
    val errors: List<String> = emptyList(),
    val isSaving: Boolean = false,
    val isSaved: Boolean = false,
) {
    val isEditMode: Boolean get() = productId != null
    /** Live preview per spec §1: sellingPrice − purchasePrice − packagingCost. */
    val estimatedProfitPreview: Money
        get() = Money((sellingPrice.toLongOrNull() ?: 0) - (purchasePrice.toLongOrNull() ?: 0) - (packagingCost.toLongOrNull() ?: 0))
}

@HiltViewModel
class ProductFormViewModel @Inject constructor(
    private val productRepository: ProductRepository,
    private val categoryRepository: CategoryRepository,
    private val validateProduct: ValidateProductUseCase,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val _state = MutableStateFlow(ProductFormState(productId = savedStateHandle.get<Long>("productId")))
    val state: StateFlow<ProductFormState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            categoryRepository.observeAll().collect { categories ->
                _state.update { it.copy(categories = categories) }
            }
        }
        _state.value.productId?.let { id ->
            viewModelScope.launch {
                productRepository.getById(id)?.let { product -> _state.update { it.fromProduct(product) } }
            }
        }
    }

    fun onNameChange(v: String) = _state.update { it.copy(name = v) }
    fun onSkuChange(v: String) = _state.update { it.copy(sku = v) }
    fun onBarcodeChange(v: String) = _state.update { it.copy(barcode = v) }
    fun onCategoryChange(v: Long?) = _state.update { it.copy(categoryId = v) }
    fun onSellingPriceChange(v: String) = _state.update { it.copy(sellingPrice = v.filter { c -> c.isDigit() }) }
    fun onPurchasePriceChange(v: String) = _state.update { it.copy(purchasePrice = v.filter { c -> c.isDigit() }) }
    fun onPackagingCostChange(v: String) = _state.update { it.copy(packagingCost = v.filter { c -> c.isDigit() }) }
    fun onStockChange(v: String) = _state.update { it.copy(stockQuantity = v.filter { c -> c.isDigit() }) }
    fun onMinimumStockChange(v: String) = _state.update { it.copy(minimumStock = v.filter { c -> c.isDigit() }) }
    fun onNotesChange(v: String) = _state.update { it.copy(notes = v) }

    fun save() {
        val s = _state.value
        val draft = ProductDraft(
            name = s.name,
            sku = s.sku,
            sellingPrice = Money(s.sellingPrice.toLongOrNull() ?: 0),
            purchasePrice = Money(s.purchasePrice.toLongOrNull() ?: 0),
            packagingCost = Money(s.packagingCost.toLongOrNull() ?: 0),
            stockQuantity = s.stockQuantity.toIntOrNull() ?: 0,
            minimumStock = s.minimumStock.toIntOrNull() ?: 0,
        )
        val result = validateProduct(draft)
        if (result is ValidationResult.Invalid) {
            _state.update { it.copy(errors = result.messages) }
            return
        }

        viewModelScope.launch {
            _state.update { it.copy(isSaving = true, errors = emptyList()) }
            val now = System.currentTimeMillis()
            if (s.isEditMode) {
                productRepository.update(
                    Product(
                        id = s.productId!!, name = draft.name, sku = draft.sku,
                        barcode = s.barcode.ifBlank { null }, categoryId = s.categoryId,
                        purchasePrice = draft.purchasePrice, sellingPrice = draft.sellingPrice,
                        stockQuantity = draft.stockQuantity, minimumStock = draft.minimumStock,
                        supplierId = s.supplierId, packagingCost = draft.packagingCost,
                        notes = s.notes.ifBlank { null }, createdAt = now, updatedAt = now,
                    ),
                )
            } else {
                productRepository.create(
                    Product(
                        name = draft.name, sku = draft.sku, barcode = s.barcode.ifBlank { null },
                        categoryId = s.categoryId, purchasePrice = draft.purchasePrice,
                        sellingPrice = draft.sellingPrice, stockQuantity = draft.stockQuantity,
                        minimumStock = draft.minimumStock, supplierId = s.supplierId,
                        packagingCost = draft.packagingCost, notes = s.notes.ifBlank { null },
                        createdAt = now, updatedAt = now,
                    ),
                )
            }
            _state.update { it.copy(isSaving = false, isSaved = true) }
        }
    }
}

private fun ProductFormState.fromProduct(p: Product) = copy(
    name = p.name, sku = p.sku, barcode = p.barcode.orEmpty(), categoryId = p.categoryId,
    supplierId = p.supplierId, sellingPrice = p.sellingPrice.amountInToman.toString(),
    purchasePrice = p.purchasePrice.amountInToman.toString(),
    packagingCost = p.packagingCost.amountInToman.toString(),
    stockQuantity = p.stockQuantity.toString(), minimumStock = p.minimumStock.toString(),
    notes = p.notes.orEmpty(),
)
