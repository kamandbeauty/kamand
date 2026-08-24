package com.modir.forushgah.presentation.products

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.CategoryRepository
import com.modir.forushgah.data.repository.ProductRepository
import com.modir.forushgah.domain.model.Category
import com.modir.forushgah.domain.model.Product
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class ProductListUiState(
    val isLoading: Boolean = true,
    val query: String = "",
    val selectedCategoryId: Long? = null,
    val categories: List<Category> = emptyList(),
    val products: List<Product> = emptyList(),
) {
    val isEmpty: Boolean get() = !isLoading && products.isEmpty() && query.isBlank() && selectedCategoryId == null
}

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class ProductListViewModel @Inject constructor(
    private val productRepository: ProductRepository,
    private val categoryRepository: CategoryRepository,
) : ViewModel() {

    private val query = MutableStateFlow("")
    private val selectedCategoryId = MutableStateFlow<Long?>(null)

    private val products = combine(query, selectedCategoryId) { q, categoryId -> q to categoryId }
        .flatMapLatest { (q, categoryId) ->
            when {
                q.isNotBlank() -> productRepository.observeSearch(q)
                categoryId != null -> productRepository.observeActiveProductsByCategory(categoryId)
                else -> productRepository.observeActiveProducts()
            }
        }

    val uiState: StateFlow<ProductListUiState> = combine(
        query, selectedCategoryId, products, categoryRepository.observeAll(),
    ) { q, categoryId, productList, categories ->
        ProductListUiState(
            isLoading = false,
            query = q,
            selectedCategoryId = categoryId,
            categories = categories,
            products = productList,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ProductListUiState())

    fun onQueryChange(value: String) { query.value = value }
    fun onCategorySelected(categoryId: Long?) { selectedCategoryId.value = categoryId }
}
