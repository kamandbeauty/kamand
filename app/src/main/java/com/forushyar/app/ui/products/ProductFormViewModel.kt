package com.forushyar.app.ui.products

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.forushyar.app.data.local.entity.Product
import com.forushyar.app.data.repository.ProductRepository
import com.forushyar.app.util.FormatUtils
import com.forushyar.app.util.toNonNegativeLongOrNull
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch

data class ProductFormState(
    val id: Long = 0,
    val name: String = "",
    val category: String = "",
    val buyPrice: String = "",
    val sellPrice: String = "",
    val stock: String = "",
    val createdDate: Long = System.currentTimeMillis(),
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val nameError: Boolean = false,
    val buyPriceError: Boolean = false,
    val sellPriceError: Boolean = false,
    val stockError: Boolean = false,
    val loadFailed: Boolean = false
)

sealed interface ProductFormEvent {
    data object Saved : ProductFormEvent
    data object SaveFailed : ProductFormEvent
}

/** فرم مشترک ثبت و ویرایش محصول با پشتیبانی از اعداد فارسی و لاتین. */
@HiltViewModel
class ProductFormViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repository: ProductRepository
) : ViewModel() {

    private val productId: Long = savedStateHandle.get<Long>("productId") ?: 0L
    private val _state = MutableStateFlow(ProductFormState(isLoading = productId > 0))
    val state: StateFlow<ProductFormState> = _state.asStateFlow()

    private val _events = Channel<ProductFormEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()

    init {
        if (productId > 0) loadProduct()
    }

    private fun loadProduct() {
        viewModelScope.launch {
            val product = repository.observeById(productId).first()
            _state.value = if (product == null) {
                _state.value.copy(isLoading = false, loadFailed = true)
            } else {
                ProductFormState(
                    id = product.id,
                    name = product.name,
                    category = product.category,
                    buyPrice = FormatUtils.formatNumber(product.buyPrice),
                    sellPrice = FormatUtils.formatNumber(product.sellPrice),
                    stock = FormatUtils.formatNumber(product.stock.toLong()),
                    createdDate = product.createdDate
                )
            }
        }
    }

    fun onNameChange(value: String) = update { copy(name = value, nameError = false) }
    fun onCategoryChange(value: String) = update { copy(category = value) }
    fun onBuyPriceChange(value: String) = update { copy(buyPrice = value, buyPriceError = false) }
    fun onSellPriceChange(value: String) = update { copy(sellPrice = value, sellPriceError = false) }
    fun onStockChange(value: String) = update { copy(stock = value, stockError = false) }

    private fun update(block: ProductFormState.() -> ProductFormState) {
        _state.value = _state.value.block()
    }

    fun save() {
        val current = _state.value
        val buyPrice = current.buyPrice.toNonNegativeLongOrNull()
        val sellPrice = current.sellPrice.toNonNegativeLongOrNull()
        val stockLong = current.stock.toNonNegativeLongOrNull()
        val nameError = current.name.isBlank()
        val buyPriceError = buyPrice == null
        val sellPriceError = sellPrice == null
        val stockError = stockLong == null || stockLong > Int.MAX_VALUE

        if (nameError || buyPriceError || sellPriceError || stockError) {
            _state.value = current.copy(
                nameError = nameError,
                buyPriceError = buyPriceError,
                sellPriceError = sellPriceError,
                stockError = stockError
            )
            return
        }
        if (current.isSaving || current.isLoading) return

        viewModelScope.launch {
            _state.value = current.copy(isSaving = true)
            val product = Product(
                id = current.id,
                name = current.name.trim(),
                category = current.category.trim(),
                buyPrice = checkNotNull(buyPrice),
                sellPrice = checkNotNull(sellPrice),
                stock = checkNotNull(stockLong).toInt(),
                createdDate = current.createdDate
            )
            runCatching {
                if (current.id == 0L) repository.add(product) else repository.update(product)
            }.onSuccess {
                _events.send(ProductFormEvent.Saved)
            }.onFailure {
                _state.value = _state.value.copy(isSaving = false)
                _events.send(ProductFormEvent.SaveFailed)
            }
        }
    }
}
