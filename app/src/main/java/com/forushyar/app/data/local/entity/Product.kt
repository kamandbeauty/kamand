package com.forushyar.app.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * جدول محصولات
 */
@Entity(tableName = "products")
data class Product(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val name: String,
    val category: String = "",
    val buyPrice: Long = 0,
    val sellPrice: Long = 0,
    val stock: Int = 0,
    val createdDate: Long = System.currentTimeMillis()
)
