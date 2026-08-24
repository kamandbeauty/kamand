package com.modir.forushgah.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.modir.forushgah.domain.model.InventoryMovementType
import com.modir.forushgah.domain.model.InventoryReferenceType

@Entity(
    tableName = "inventory_movements",
    foreignKeys = [
        ForeignKey(entity = ProductEntity::class, parentColumns = ["id"], childColumns = ["productId"], onDelete = ForeignKey.CASCADE),
    ],
    indices = [Index("productId"), Index("referenceId"), Index("createdAt")],
)
data class InventoryMovementEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val productId: Long,
    val quantityDelta: Int,
    val movementType: InventoryMovementType,
    val referenceType: InventoryReferenceType = InventoryReferenceType.NONE,
    val referenceId: Long? = null,
    val note: String? = null,
    val stockBefore: Int,
    val stockAfter: Int,
    val createdAt: Long,
)
