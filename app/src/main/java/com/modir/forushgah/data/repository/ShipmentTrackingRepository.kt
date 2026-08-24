package com.modir.forushgah.data.repository

import androidx.room.withTransaction
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.dao.OrderDao
import com.modir.forushgah.data.local.dao.ShipmentTrackingEntityRow
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/** One row of the «کدهای رهگیری ارسال» screen (spec §17–§20): tracking
 * belongs to the ORDER, never to the customer. */
data class ShipmentTrackingRow(
    val orderId: Long,
    val orderNumber: String,
    val customerId: Long?,
    val customerName: String,
    val customerMobile: String?,
    val providerId: Long?,
    val providerName: String?,
    val trackingCode: String?,
    val shippedAt: Long?,
    val orderDate: Long,
    val isPurchase: Boolean,
) {
    val hasTracking: Boolean get() = !trackingCode.isNullOrBlank()
    val isShipped: Boolean get() = hasTracking || shippedAt != null || providerId != null
    val isUnshipped: Boolean get() = !isShipped
}

/** One order's tracking update. [trackingCode] is a String passed through
 * exactly as entered (leading zeros, letters, hyphens preserved — spec §21). */
data class ShipmentTrackingUpdate(
    val orderId: Long,
    val providerId: Long?,
    val trackingCode: String?,
    val shippedAt: Long?,
)

/**
 * Phase 3.1 shipment tracking — the order's own shipping columns are the only
 * source of truth (no second shipment table, no customer-level tracking).
 * The invoice reads the same data through the existing Order engine.
 */
@Singleton
class ShipmentTrackingRepository @Inject constructor(
    private val database: AppDatabase,
    private val orderDao: OrderDao,
) {

    /** All orders as tracking rows; [query] is a database-level
     * customer/supplier name search (spec §24). */
    fun observeForTracking(query: String): Flow<List<ShipmentTrackingRow>> =
        orderDao.observeForShipmentTracking(query).map { list ->
            list.map { it.toRow() }
        }

    suspend fun saveTracking(update: ShipmentTrackingUpdate) = database.withTransaction {
        saveOne(update)
    }

    /**
     * Bulk save (spec §27–§29): every modified row commits in ONE database
     * transaction; any failure rolls back the whole batch — the database is
     * never left half-saved. Returns the number of saved rows.
     */
    suspend fun bulkSaveTracking(updates: List<ShipmentTrackingUpdate>): Int =
        database.withTransaction {
            updates.forEach { saveOne(it) }
            updates.size
        }

    private suspend fun saveOne(u: ShipmentTrackingUpdate) {
        val normalizedCode = u.trackingCode?.trim()?.takeIf { it.isNotEmpty() }
        val affected = orderDao.updateShipping(
            orderId = u.orderId,
            providerId = u.providerId,
            trackingCode = normalizedCode,
            shippedAt = u.shippedAt,
            updatedAt = System.currentTimeMillis(),
        )
        if (affected == 0) error("سفارش ${u.orderId} یافت نشد")
    }
}

private fun ShipmentTrackingEntityRow.toRow() = ShipmentTrackingRow(
    orderId = order.id,
    orderNumber = order.orderNumber,
    customerId = order.customerId,
    customerName = partyName,
    customerMobile = partyMobile,
    providerId = order.shippingProviderId,
    providerName = providerName,
    trackingCode = order.trackingCode,
    shippedAt = order.shippedAt,
    orderDate = order.orderDate,
    isPurchase = order.kind == com.modir.forushgah.domain.model.OrderKind.PURCHASE,
)
