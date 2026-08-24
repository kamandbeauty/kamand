package com.modir.forushgah.presentation.products

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.data.repository.ProductRepository
import com.modir.forushgah.data.repository.InventoryRepository
import com.modir.forushgah.domain.model.InventoryMovement
import com.modir.forushgah.domain.model.Product
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class ProductDetailUiState(
    val isLoading: Boolean = true,
    val product: Product? = null,
    val movements: List<InventoryMovement> = emptyList(),
)

@HiltViewModel
class ProductDetailViewModel @Inject constructor(
    productRepository: ProductRepository,
    inventoryRepository: InventoryRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val productId: Long = checkNotNull(savedStateHandle["productId"])

    val uiState: StateFlow<ProductDetailUiState> = combine(
        productRepository.observeById(productId),
        inventoryRepository.observeMovementsForProduct(productId),
    ) { product, movements ->
        ProductDetailUiState(isLoading = false, product = product, movements = movements)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ProductDetailUiState())
}
