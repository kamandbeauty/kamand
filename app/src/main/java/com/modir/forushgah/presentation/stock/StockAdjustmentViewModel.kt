package com.modir.forushgah.presentation.stock

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.InventoryRepository
import com.modir.forushgah.data.repository.ProductRepository
import com.modir.forushgah.domain.model.Product
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class StockAdjustmentUiState(
    val isLoading: Boolean = true,
    val query: String = "",
    val products: List<Product> = emptyList(),
    val selectedProduct: Product? = null,
)

sealed interface StockAdjustmentEvent {
    data object Adjusted : StockAdjustmentEvent
    data class Error(val message: String) : StockAdjustmentEvent
}

/**
 * Standalone stock-adjustment screen (spec §4): the user picks a product,
 * sees the current stock, enters the NEW stock and a reason; the system
 * calculates the difference automatically and records an
 * ADJUSTMENT_IN/ADJUSTMENT_OUT movement via the only legitimate
 * stock-mutation path ([InventoryRepository]).
 */
@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class StockAdjustmentViewModel @Inject constructor(
    private val productRepository: ProductRepository,
    private val inventoryRepository: InventoryRepository,
) : ViewModel() {

    private val query = MutableStateFlow("")
    private val selectedProductId = MutableStateFlow<Long?>(null)

    private val productsFlow = combine(query, selectedProductId) { q, id -> q to id }
        .flatMapLatest { (q, id) ->
            when {
                id != null -> productRepository.observeById(id).map { listOfNotNull(it) }
                q.isNotBlank() -> productRepository.observeSearch(q)
                else -> productRepository.observeActiveProducts()
            }
        }

    val uiState: StateFlow<StockAdjustmentUiState> = combine(productsFlow, query) { products, q ->
        StockAdjustmentUiState(
            isLoading = false,
            query = q,
            products = products,
            selectedProduct = products.firstOrNull { it.id == selectedProductId.value },
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), StockAdjustmentUiState())

    private val _event = MutableStateFlow<StockAdjustmentEvent?>(null)
    val event: StateFlow<StockAdjustmentEvent?> = _event.asStateFlow()

    fun consumeEvent() {
        _event.value = null
    }

    fun onQueryChange(value: String) {
        query.value = value
    }

    fun onProductSelected(productId: Long) {
        selectedProductId.value = productId
        query.value = ""
    }

    fun onProductCleared() {
        selectedProductId.value = null
    }

    /** The system computes the difference (new - current) and creates the
     * movement automatically — the user never touches a delta directly. */
    fun confirm(newStock: Int, reason: String?) {
        val productId = selectedProductId.value ?: return
        viewModelScope.launch {
            try {
                inventoryRepository.adjustStockTo(productId, newStock, reason)
                _event.value = StockAdjustmentEvent.Adjusted
            } catch (e: Exception) {
                _event.value = StockAdjustmentEvent.Error(e.message ?: "تنظیم موجودی با خطا مواجه شد")
            }
        }
    }
}
