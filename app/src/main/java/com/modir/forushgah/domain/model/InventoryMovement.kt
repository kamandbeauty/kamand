package com.modir.forushgah.domain.model

enum class InventoryMovementType {
    PURCHASE, SALE, RETURN, ADJUSTMENT_IN, ADJUSTMENT_OUT, DAMAGED, OTHER
}

/** What kind of record a movement's [InventoryMovement.referenceId] points to, if any. */
enum class InventoryReferenceType {
    ORDER, STOCK_ADJUSTMENT, MANUAL, NONE,
    ORDER_RETURN, // referenceId = the OrderReturn id (restock on return/cancel)
}

/**
 * Every stock change in the app MUST be represented by one of these.
 * Product.stockQuantity is a derived cache; the movement log is the
 * source of truth and must be reconstructable at any point in time.
 */
data class InventoryMovement(
    val id: Long = 0,
    val productId: Long,
    val quantityDelta: Int, // positive = stock added, negative = stock removed
    val movementType: InventoryMovementType,
    val referenceType: InventoryReferenceType = InventoryReferenceType.NONE,
    val referenceId: Long? = null,
    val note: String? = null,
    val stockBefore: Int,
    val stockAfter: Int,
    val createdAt: Long,
)
