package com.forushyar.app.ui.products

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.forushyar.app.data.local.entity.Product
import com.forushyar.app.data.repository.ProductRepository
import com.forushyar.app.data.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class ProductDetailState(
    val product: Product? = null,
    val confirmDeletion: Boolean = true,
    val isLoading: Boolean = true
)

sealed interface ProductDetailEvent {
    data object Deleted : ProductDetailEvent
    data object DeleteFailed : ProductDetailEvent
}

@HiltViewModel
class ProductDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repository: ProductRepository,
    settingsRepository: SettingsRepository
) : ViewModel() {

    val productId: Long = checkNotNull(savedStateHandle.get<Long>("productId"))

    val state: StateFlow<ProductDetailState> = combine(
        repository.observeById(productId),
        settingsRepository.settings
    ) { product, settings ->
        ProductDetailState(
            product = product,
            confirmDeletion = settings.confirmDeletion,
            isLoading = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = ProductDetailState()
    )

    private val _events = Channel<ProductDetailEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()
    private var deleteInProgress = false

    fun deleteProduct() {
        val product = state.value.product ?: return
        if (deleteInProgress) return
        deleteInProgress = true
        viewModelScope.launch {
            runCatching { repository.delete(product) }
                .onSuccess { _events.send(ProductDetailEvent.Deleted) }
                .onFailure {
                    deleteInProgress = false
                    _events.send(ProductDetailEvent.DeleteFailed)
                }
        }
    }
}
