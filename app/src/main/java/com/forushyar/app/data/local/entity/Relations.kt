package com.forushyar.app.data.local.entity

import androidx.room.Embedded
import androidx.room.Relation

/**
 * سفارش به همراه اقلامش
 */
data class OrderWithItems(
    @Embedded val order: Order,
    @Relation(
        parentColumn = "id",
        entityColumn = "orderId"
    )
    val items: List<OrderItem> = emptyList()
) {
    val total: Long get() = items.sumOf { it.total }
    val profit: Long get() = items.sumOf { it.profit }
}

/**
 * سفارش به همراه مشتری و اقلام — برای نمایش در لیست سفارش‌ها و داشبورد.
 * (Room از چند @Relation در یک POJO پشتیبانی می‌کند.)
 */
data class OrderDetails(
    @Embedded val order: Order,
    @Relation(
        parentColumn = "customerId",
        entityColumn = "id"
    )
    val customer: Customer,
    @Relation(
        parentColumn = "id",
        entityColumn = "orderId"
    )
    val items: List<OrderItem> = emptyList()
) {
    val total: Long get() = items.sumOf { it.total }
    val profit: Long get() = items.sumOf { it.profit }
}

/**
 * مشتری به همراه سفارش‌هایش (تاریخچه مشتری)
 */
data class CustomerWithOrders(
    @Embedded val customer: Customer,
    @Relation(
        parentColumn = "id",
        entityColumn = "customerId"
    )
    val orders: List<Order> = emptyList()
)
