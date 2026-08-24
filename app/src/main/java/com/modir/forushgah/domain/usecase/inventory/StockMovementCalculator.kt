package com.modir.forushgah.domain.usecase.inventory

import com.modir.forushgah.domain.model.InsufficientStockException

/** Result of applying a delta to a stock level — pure math, no I/O. */
data class StockMovementResult(
    val stockBefore: Int,
    val stockAfter: Int,
    val delta: Int,
)

/**
 * The single rule governing every stock mutation in the app: stock may never
 * go negative (default policy, per spec §16). Kept as a pure function,
 * separate from [com.modir.forushgah.data.repository.InventoryRepository],
 * so it's testable without Room/Robolectric/an emulator.
 */
object StockMovementCalculator {

    fun applyDelta(productId: Long, currentStock: Int, delta: Int): StockMovementResult {
        val newStock = currentStock + delta
        if (newStock < 0) {
            throw InsufficientStockException(productId = productId, requested = -delta, available = currentStock)
        }
        return StockMovementResult(stockBefore = currentStock, stockAfter = newStock, delta = delta)
    }

    /** Stock-adjustment screen: user enters an absolute new stock value; we derive the delta. */
    fun adjustTo(currentStock: Int, newStock: Int): StockMovementResult =
        StockMovementResult(stockBefore = currentStock, stockAfter = newStock, delta = newStock - currentStock)

    fun isLowStock(stockQuantity: Int, minimumStock: Int): Boolean = stockQuantity <= minimumStock
}
