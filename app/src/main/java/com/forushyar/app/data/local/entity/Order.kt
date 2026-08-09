package com.forushyar.app.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * وضعیت سفارش
 */
enum class OrderStatus {
    NEW,
    PREPARING,
    SENT,
    DELIVERED,
    CANCELLED
}

/**
 * جدول سفارش‌ها
 *
 * حذف مشتری، سفارش‌های او و به‌صورت زنجیره‌ای اقلام آن‌ها را حذف می‌کند (CASCADE).
 */
@Entity(
    tableName = "orders",
    foreignKeys = [
        ForeignKey(
            entity = Customer::class,
            parentColumns = ["id"],
            childColumns = ["customerId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("customerId")]
)
data class Order(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val customerId: Long,
    val status: OrderStatus = OrderStatus.NEW,
    val createdAt: Long = System.currentTimeMillis(),
    val note: String = ""
)
