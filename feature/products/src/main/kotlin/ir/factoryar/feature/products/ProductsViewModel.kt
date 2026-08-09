package ir.factoryar.feature.products

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import ir.factoryar.core.domain.model.InventorySummary
import ir.factoryar.core.domain.model.Product
import ir.factoryar.core.domain.model.ProductCategory
import ir.factoryar.core.domain.model.ProductWithCategory
import ir.factoryar.core.domain.model.StockMoveReason
import ir.factoryar.core.domain.repository.ProductFilter
import ir.factoryar.core.domain.repository.ProductRepository
import ir.factoryar.core.domain.usecase.FindProductByBarcodeUseCase
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ProductsUiState(
    val query: String = "",
    val filter: ProductFilter = ProductFilter.ALL,
    val categoryId: Long? = null,
    val products: List<ProductWithCategory> = emptyList(),
    val categories: List<ProductCategory> = emptyList(),
    val summary: InventorySummary = InventorySummary(),
    val isLoading: Boolean = true,
    /** پیام کوتاه برای Snackbar */
    val message: String? = null,
)

private data class Filters(val query: String, val filter: ProductFilter, val categoryId: Long?)

@HiltViewModel
class ProductsViewModel @Inject constructor(
    private val repository: ProductRepository,
    private val findByBarcode: FindProductByBarcodeUseCase,
) : ViewModel() {

    private val filters = MutableStateFlow(Filters("", ProductFilter.ALL, null))
    private val message = MutableStateFlow<String?>(null)

    @OptIn(ExperimentalCoroutinesApi::class)
    private val products = filters.flatMapLatest { f ->
        repository.observeProducts(f.query, f.categoryId, f.filter)
    }

    val uiState: StateFlow<ProductsUiState> = combine(
        filters,
        products,
        repository.observeCategories(),
        repository.observeInventorySummary(),
        message,
    ) { f, list, categories, summary, msg ->
        ProductsUiState(
            query = f.query,
            filter = f.filter,
            categoryId = f.categoryId,
            products = list,
            categories = categories,
            summary = summary,
            isLoading = false,
            message = msg,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ProductsUiState())

    fun setQuery(query: String) { filters.value = filters.value.copy(query = query) }
    fun setFilter(filter: ProductFilter) { filters.value = filters.value.copy(filter = filter) }
    fun setCategory(categoryId: Long?) { filters.value = filters.value.copy(categoryId = categoryId) }
    fun consumeMessage() { message.value = null }

    /** اسکن بارکد در صفحه انبار: اگر کالا موجود بود پیدایش می‌کند */
    fun onBarcodeScanned(barcode: String, onFound: (Product) -> Unit, onNotFound: (String) -> Unit) {
        viewModelScope.launch {
            val product = findByBarcode(barcode)
            if (product != null) onFound(product) else onNotFound(barcode)
        }
    }

    fun deleteProduct(id: Long) {
        viewModelScope.launch {
            repository.deleteProduct(id)
            message.value = "کالا حذف شد"
        }
    }

    fun quickAdjustStock(productId: Long, delta: Double) {
        viewModelScope.launch {
            repository.adjustStock(productId, delta, StockMoveReason.MANUAL, note = "اصلاح سریع از لیست انبار")
        }
    }

    fun saveCategory(name: String) {
        viewModelScope.launch {
            if (name.isNotBlank()) repository.saveCategory(ProductCategory(name = name.trim()))
        }
    }

    fun deleteCategory(id: Long) {
        viewModelScope.launch { repository.deleteCategory(id) }
    }
}
