package com.forushyar.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.forushyar.app.data.local.dao.CustomerDao
import com.forushyar.app.data.local.dao.OrderDao
import com.forushyar.app.data.local.dao.OrderItemDao
import com.forushyar.app.data.local.dao.ProductDao
import com.forushyar.app.data.local.entity.Customer
import com.forushyar.app.data.local.entity.Order
import com.forushyar.app.data.local.entity.OrderItem
import com.forushyar.app.data.local.entity.Product

@Database(
    entities = [
        Customer::class,
        Product::class,
        Order::class,
        OrderItem::class
    ],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {

    abstract fun customerDao(): CustomerDao
    abstract fun productDao(): ProductDao
    abstract fun orderDao(): OrderDao
    abstract fun orderItemDao(): OrderItemDao
}
