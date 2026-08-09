package ir.factoryar.core.domain.usecase

import ir.factoryar.core.domain.model.Product
import ir.factoryar.core.domain.model.StockMoveReason
import ir.factoryar.core.domain.repository.ProductFilter
import ir.factoryar.core.domain.repository.ProductRepository
import javax.inject.Inject

class ObserveProductsUseCase @Inject constructor(private val repo: ProductRepository) {
    operator fun invoke(query: String = "", categoryId: Long? = null, filter: ProductFilter = ProductFilter.ALL) =
        repo.observeProducts(query, categoryId, filter)
}

class SaveProductUseCase @Inject constructor(private val repo: ProductRepository) {
    suspend operator fun invoke(product: Product): Long {
        require(product.name.isNotBlank()) { "نام کالا الزامی است" }
        return repo.saveProduct(product)
    }
}

class DeleteProductUseCase @Inject constructor(private val repo: ProductRepository) {
    suspend operator fun invoke(id: Long) = repo.deleteProduct(id)
}

/** جستجوی کالا با بارکد اسکن‌شده (افزودن سریع به فاکتور) */
class FindProductByBarcodeUseCase @Inject constructor(private val repo: ProductRepository) {
    suspend operator fun invoke(barcode: String): Product? {
        val normalized = barcode.trim()
        if (normalized.isEmpty()) return null
        return repo.findByBarcode(normalized)
    }
}

class AdjustStockUseCase @Inject constructor(private val repo: ProductRepository) {
    suspend operator fun invoke(
        productId: Long,
        delta: Double,
        reason: StockMoveReason = StockMoveReason.MANUAL,
        note: String = "",
    ) = repo.adjustStock(productId, delta, reason, note = note)
}

class ObserveInventorySummaryUseCase @Inject constructor(private val repo: ProductRepository) {
    operator fun invoke() = repo.observeInventorySummary()
}

class ObserveLowStockUseCase @Inject constructor(private val repo: ProductRepository) {
    operator fun invoke() = repo.observeLowStock()
}
