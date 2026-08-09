package com.forushyar.app.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * جدول مشتری‌ها
 */
@Entity(tableName = "customers")
data class Customer(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val name: String,
    val phone: String = "",
    val instagramId: String = "",
    val address: String = "",
    val note: String = "",
    val createdDate: Long = System.currentTimeMillis()
)
