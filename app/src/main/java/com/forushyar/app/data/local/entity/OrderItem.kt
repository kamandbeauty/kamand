package com.forushyar.app.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * اقلام هر سفارش
 *
 * رابطه: هر سفارش شامل چند OrderItem است و هر OrderItem به یک محصول اشاره می‌کند.
 * قیمت خرید و فروش در زمان ثبت سفارش «عکس» گرفته می‌شود تا تغییر قیمت محصول
 * روی سفارش‌های گذشته اثر نگذارد.
 */
@Entity(
    tableName = "order_items",
    foreignKeys = [
        ForeignKey(
            entity = Order::class,
            parentColumns = ["id"],
            childColumns = ["orderId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("orderId"), Index("productId")]
)
data class OrderItem(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val orderId: Long,
    val productId: Long,
    val quantity: Int = 1,
    val buyPrice: Long = 0,
    val sellPrice: Long = 0
) {
    /** سود این قلم = (قیمت فروش - قیمت خرید) × تعداد */
    val profit: Long
        get() = (sellPrice - buyPrice) * quantity

    /** جمع فروش این قلم */
    val total: Long
        get() = sellPrice * quantity
}
