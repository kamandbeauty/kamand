package com.modir.forushgah.data.repository

import androidx.room.withTransaction
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.dao.InventoryMovementDao
import com.modir.forushgah.data.local.entity.InventoryMovementEntity
import com.modir.forushgah.domain.model.InventoryMovement
import com.modir.forushgah.domain.model.InventoryMovementType
import com.modir.forushgah.domain.model.InventoryReferenceType
import com.modir.forushgah.domain.usecase.inventory.StockMovementCalculator
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The ONLY place in the app allowed to change [ProductEntity.stockQuantity].
 * Every call is one atomic DB transaction: read current stock -> validate ->
 * write the movement row (with before/after snapshot) -> update the product's
 * cached stock. Nothing else should touch stockQuantity directly (see
 * spec §3: "Never directly manipulate stock without creating an
 * InventoryMovement").
 */
@Singleton
class InventoryRepository @Inject constructor(
    private val database: AppDatabase,
    private val inventoryMovementDao: InventoryMovementDao,
) {
    fun observeMovementsForProduct(productId: Long): Flow<List<InventoryMovement>> =
        inventoryMovementDao.observeForProduct(productId).map { list -> list.map { it.toDomain() } }

    /**
     * Applies [quantityDelta] to [productId]'s stock (positive = add, negative = remove)
     * and records the movement. Throws [InsufficientStockException] if the result
     * would go below zero (default, non-negative-stock policy).
     */
    suspend fun applyMovement(
        productId: Long,
        quantityDelta: Int,
        movementType: InventoryMovementType,
        referenceType: InventoryReferenceType = InventoryReferenceType.NONE,
        referenceId: Long? = null,
        note: String? = null,
        now: Long = System.currentTimeMillis(),
    ): InventoryMovement = database.withTransaction {
        val currentStock = inventoryMovementDao.getCurrentStock(productId)
            ?: error("Product $productId not found")
        val result = StockMovementCalculator.applyDelta(productId, currentStock, quantityDelta)
        val newStock = result.stockAfter

        val entity = InventoryMovementEntity(
            productId = productId,
            quantityDelta = quantityDelta,
            movementType = movementType,
            referenceType = referenceType,
            referenceId = referenceId,
            note = note,
            stockBefore = currentStock,
            stockAfter = newStock,
            createdAt = now,
        )
        val id = inventoryMovementDao.insert(entity)
        inventoryMovementDao.setStock(productId, newStock, now)

        entity.copy(id = id).toDomain()
    }

    /**
     * Stock adjustment screen entry point (spec §4): user picks a NEW absolute
     * stock value; we compute the delta and record ADJUSTMENT_IN/ADJUSTMENT_OUT.
     */
    suspend fun adjustStockTo(
        productId: Long,
        newStock: Int,
        reason: String?,
        now: Long = System.currentTimeMillis(),
    ): InventoryMovement = database.withTransaction {
        val currentStock = inventoryMovementDao.getCurrentStock(productId)
            ?: error("Product $productId not found")
        val result = StockMovementCalculator.adjustTo(currentStock, newStock)
        val delta = result.delta
        val type = if (delta >= 0) InventoryMovementType.ADJUSTMENT_IN else InventoryMovementType.ADJUSTMENT_OUT

        val entity = InventoryMovementEntity(
            productId = productId,
            quantityDelta = delta,
            movementType = type,
            referenceType = InventoryReferenceType.STOCK_ADJUSTMENT,
            referenceId = null,
            note = reason,
            stockBefore = currentStock,
            stockAfter = newStock,
            createdAt = now,
        )
        val id = inventoryMovementDao.insert(entity)
        inventoryMovementDao.setStock(productId, newStock, now)

        entity.copy(id = id).toDomain()
    }
}

private fun InventoryMovementEntity.toDomain() = InventoryMovement(
    id = id,
    productId = productId,
    quantityDelta = quantityDelta,
    movementType = movementType,
    referenceType = referenceType,
    referenceId = referenceId,
    note = note,
    stockBefore = stockBefore,
    stockAfter = stockAfter,
    createdAt = createdAt,
)
