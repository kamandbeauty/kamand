package com.modir.forushgah.presentation.products

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.CategoryRepository
import com.modir.forushgah.data.repository.InventoryRepository
import com.modir.forushgah.data.repository.ProductRepository
import com.modir.forushgah.domain.model.InventoryMovement
import com.modir.forushgah.domain.model.Product
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ProductDetailUiState(
    val isLoading: Boolean = true,
    val product: Product? = null,
    val categoryName: String? = null,
    val movements: List<InventoryMovement> = emptyList(),
)

/** One-shot user-action events, consumed by the UI layer. */
sealed interface ProductDetailEvent {
    data object StockAdjusted : ProductDetailEvent
    data object ProductArchived : ProductDetailEvent
    data class Error(val message: String) : ProductDetailEvent
}

@HiltViewModel
class ProductDetailViewModel @Inject constructor(
    private val productRepository: ProductRepository,
    private val inventoryRepository: InventoryRepository,
    private val categoryRepository: CategoryRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val productId: Long = checkNotNull(savedStateHandle["productId"])

    val uiState: StateFlow<ProductDetailUiState> = combine(
        productRepository.observeById(productId),
        inventoryRepository.observeMovementsForProduct(productId),
        categoryRepository.observeAll(),
    ) { product, movements, categories ->
        ProductDetailUiState(
            isLoading = false,
            product = product,
            categoryName = categories.find { it.id == product?.categoryId }?.name,
            movements = movements,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ProductDetailUiState())

    private val _event = MutableStateFlow<ProductDetailEvent?>(null)
    val event: StateFlow<ProductDetailEvent?> = _event.asStateFlow()

    fun consumeEvent() {
        _event.value = null
    }

    /** Stock adjustment (spec §4): user picks a NEW absolute stock value; the
     * repository computes the delta and records ADJUSTMENT_IN/ADJUSTMENT_OUT. */
    fun adjustStock(newStock: Int, reason: String?) {
        viewModelScope.launch {
            try {
                inventoryRepository.adjustStockTo(productId, newStock, reason)
                _event.value = ProductDetailEvent.StockAdjusted
            } catch (e: Exception) {
                _event.value = ProductDetailEvent.Error(e.message ?: "تنظیم موجودی با خطا مواجه شد")
            }
        }
    }

    fun archiveProduct() {
        viewModelScope.launch {
            try {
                productRepository.archive(productId)
                _event.value = ProductDetailEvent.ProductArchived
            } catch (e: Exception) {
                _event.value = ProductDetailEvent.Error(e.message ?: "بایگانی محصول با خطا مواجه شد")
            }
        }
    }
}
