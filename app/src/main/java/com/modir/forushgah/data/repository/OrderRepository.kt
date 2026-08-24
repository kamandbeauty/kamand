package com.modir.forushgah.data.repository

import androidx.room.withTransaction
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.dao.CustomerDao
import com.modir.forushgah.data.local.dao.InventoryMovementDao
import com.modir.forushgah.data.local.dao.OrderDao
import com.modir.forushgah.data.local.dao.OrderWithCustomer
import com.modir.forushgah.data.local.dao.PaymentDao
import com.modir.forushgah.data.local.dao.RefundDao
import com.modir.forushgah.data.local.dao.OrderReturnDao
import com.modir.forushgah.data.local.dao.ReturnWithOrder
import com.modir.forushgah.data.local.dao.OrderItemWithProduct
import com.modir.forushgah.data.local.entity.FinancialTransactionEntity
import com.modir.forushgah.data.local.entity.OrderEntity
import com.modir.forushgah.data.local.entity.OrderItemEntity
import com.modir.forushgah.data.local.entity.OrderReturnEntity
import com.modir.forushgah.data.local.entity.OrderReturnItemEntity
import com.modir.forushgah.data.local.entity.PaymentEntity
import com.modir.forushgah.data.local.entity.RefundEntity
import com.modir.forushgah.data.local.dao.FinancialTransactionDao
import com.modir.forushgah.domain.model.InventoryMovementType
import com.modir.forushgah.domain.model.InventoryReferenceType
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ReturnReason
import com.modir.forushgah.domain.model.ReturnStatus
import com.modir.forushgah.domain.model.ShippingPaymentType
import com.modir.forushgah.domain.model.TransactionType
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

/** One line of a new order (spec §3/§5). Prices are snapshots at order time. */
data class NewOrderItem(
    val productId: Long,
    val quantity: Int,
    val unitSellingPrice: Money,
    val unitPurchasePrice: Money,
    val discount: Money = Money.ZERO,
)

/** All inputs for [OrderRepository.createOrder] — validated upstream by
 * `ValidateOrderUseCase` before reaching the repository. */
data class NewOrder(
    val customerId: Long,
    val items: List<NewOrderItem>,
    val orderDiscount: Money = Money.ZERO,
    val salesChannelId: Long? = null,
    val paymentMethodId: Long? = null,
    val paymentMethodLabel: String = "نقدی",
    val shippingProviderId: Long? = null,
    val shippingPaymentType: ShippingPaymentType = ShippingPaymentType.SELLER_PAID,
    val shippingChargedToCustomer: Money = Money.ZERO,
    val actualShippingCost: Money = Money.ZERO,
    val packagingCost: Money = Money.ZERO,
    val notes: String? = null,
    val orderDate: Long = System.currentTimeMillis(),
)

/** One line of a return draft (spec §21). */
data class ReturnItemDraft(val productId: Long, val quantity: Int)

data class OrderDetail(
    val order: OrderEntity,
    val items: List<OrderItemWithProduct>,
    val customerName: String?,
    val customerMobile: String?,
    val payments: List<PaymentEntity>,
    val refunds: List<RefundEntity>,
    val returns: List<OrderReturnEntity>,
    val returnItems: List<OrderReturnItemEntity>,
) {
    val totalPaid: Money get() = Money(payments.sumOf { it.amount.amountInToman })
    val totalRefunded: Money get() = Money(refunds.sumOf { it.amount.amountInToman })
    val total: Money
        get() {
            val subtotal = Money.sum(items.map { it.item.let { i -> Money(i.unitSellingPrice.amountInToman * i.quantity - i.discount.amountInToman) } }) - order.discount
            val shipping =
                if (order.shippingPaymentType == ShippingPaymentType.CUSTOMER_PREPAID) order.shippingChargedToCustomer
                else Money.ZERO
            return subtotal + shipping
        }
    val remaining: Money get() = (total - totalPaid).coerceAtLeastZero()

    /** Units already returned per product (rejected returns excluded) — used
     * to cap partial returns (spec §21). */
    val returnedQuantityByProduct: Map<Long, Int>
        get() {
            val validReturnIds = returns.filter { it.status != ReturnStatus.REJECTED }.map { it.id }.toSet()
            return returnItems
                .filter { it.returnId in validReturnIds }
                .groupBy({ it.productId }, { it.quantity })
                .mapValues { entry -> entry.value.sum() }
        }
}

/**
 * Order lifecycle (spec §19–§24) — the operational core Phase 4 builds on.
 *
 * Every state change is ONE Room transaction (order + items + inventory
 * movements + financial events commit together or not at all). Inventory is
 * mutated only through [InventoryRepository]; movements are keyed by
 * (referenceType, referenceId, movementType) and guarded by
 * `countByReference`, so the same order can never deduct or restore stock
 * twice — even if the UI double-fires (spec §19 idempotency).
 */
@Singleton
class OrderRepository @Inject constructor(
    private val database: AppDatabase,
    private val orderDao: OrderDao,
    private val orderReturnDao: OrderReturnDao,
    private val paymentDao: PaymentDao,
    private val refundDao: RefundDao,
    private val customerDao: CustomerDao,
    private val inventoryMovementDao: InventoryMovementDao,
    private val financialTransactionDao: FinancialTransactionDao,
    private val inventoryRepository: InventoryRepository,
) {

    // ---------- read side ----------

    fun observeOrders(status: OrderStatus? = null, query: String = ""): Flow<List<OrderWithCustomer>> {
        val flow = when {
            query.isNotBlank() -> orderDao.observeSearchWithCustomer(query)
            status != null -> orderDao.observeByStatusWithCustomer(status)
            else -> orderDao.observeAllWithCustomer()
        }
        return flow
    }

    /** Returns list (spec §28) with order number + customer in one query. */
    fun observeReturns(): Flow<List<ReturnWithOrder>> =
        orderReturnDao.observeAllWithOrder()

    fun observeDetail(orderId: Long): Flow<OrderDetail?> =
        combine(
            orderDao.observeById(orderId),
            paymentDao.observeForOrder(orderId),
            refundDao.observeForOrder(orderId),
            orderReturnDao.observeForOrder(orderId),
        ) { order, payments, refunds, returns ->
            if (order == null) return@combine null
            val items = orderDao.getItemsWithProduct(orderId)
            val customer = order.customerId?.let { customerDao.getById(it) }
            val returnItems = returns.flatMap { r -> orderReturnDao.getItems(r.id) }
            OrderDetail(
                order = order,
                items = items,
                customerName = customer?.name,
                customerMobile = customer?.mobile,
                payments = payments,
                refunds = refunds,
                returns = returns,
                returnItems = returnItems,
            )
        }

    // ---------- write side ----------

    /**
     * Spec §3/§19/§26: create order + items + one SALE movement per item
     * atomically. Fails (rolls back everything) if any item would drive stock
     * negative — selling more than available stock is impossible by
     * construction, never silent.
     */
    suspend fun createOrder(draft: NewOrder): OrderEntity = database.withTransaction {
        val now = draft.orderDate
        val temp = OrderEntity(
            orderNumber = "TMP-${System.nanoTime()}",
            customerId = draft.customerId,
            orderDate = now,
            discount = draft.orderDiscount,
            shippingChargedToCustomer = draft.shippingChargedToCustomer,
            paymentMethodId = draft.paymentMethodId,
            salesChannelId = draft.salesChannelId,
            status = OrderStatus.NEW,
            shippingProviderId = draft.shippingProviderId,
            shippingPaymentType = draft.shippingPaymentType,
            actualShippingCost = draft.actualShippingCost,
            packagingCost = draft.packagingCost,
            notes = draft.notes,
            createdAt = now,
            updatedAt = now,
        )
        val orderId = orderDao.insertOrder(temp)
        val orderNumber = "SF-${orderId}" // final number from the unique rowid
        val order = temp.copy(id = orderId, orderNumber = orderNumber)
        orderDao.updateOrder(order)
        orderDao.insertItems(draft.items.map { it.toEntity(orderId) })

        // Inventory: SALE -qty per item. Guarded — a second call for the same
        // order never deducts again (spec §19).
        if (hasNoMovements(InventoryReferenceType.ORDER, orderId, InventoryMovementType.SALE)) {
            for (item in draft.items) {
                inventoryRepository.applyMovement(
                    productId = item.productId,
                    quantityDelta = -item.quantity,
                    movementType = InventoryMovementType.SALE,
                    referenceType = InventoryReferenceType.ORDER,
                    referenceId = orderId,
                    note = "سفارش $orderNumber",
                    now = now,
                )
            }
        }

        writeEvent(TransactionType.ORDER_CREATED, Money.ZERO, now, orderId, "ثبت سفارش $orderNumber")
        if (draft.packagingCost.isPositive) {
            writeEvent(TransactionType.PACKAGING_EXPENSE, -draft.packagingCost, now, orderId, "هزینه بسته‌بندی سفارش $orderNumber")
        }
        order
    }

    /**
     * Status transition. Cancellation always goes through the cancel logic
     * (stock restoration) so the status menu and the cancel button can never
     * diverge; cancelling a terminal order is a no-op.
     */
    suspend fun updateStatus(orderId: Long, status: OrderStatus, now: Long = System.currentTimeMillis()): OrderEntity =
        database.withTransaction {
            val order = orderDao.getById(orderId) ?: error("Order $orderId not found")
            if (order.status == status) return@withTransaction order
            if (status == OrderStatus.CANCELLED) {
                if (order.status == OrderStatus.CANCELLED || order.status == OrderStatus.RETURNED) {
                    return@withTransaction order
                }
                orderDao.updateOrder(order.copy(status = OrderStatus.CANCELLED, updatedAt = now))
                restoreStockForOrder(order, now)
                writeEvent(TransactionType.ORDER_CANCELLED, Money.ZERO, now, order.id, "لغو سفارش ${order.orderNumber}")
                return@withTransaction order.copy(status = OrderStatus.CANCELLED, updatedAt = now)
            }
            orderDao.updateOrder(order.copy(status = status, updatedAt = now))
            order.copy(status = status, updatedAt = now)
        }

    /**
     * Spec §20: cancelling an order that already deducted stock restores it —
     * one RETURN movement per item referencing the order, idempotent.
     */
    suspend fun cancelOrder(orderId: Long, now: Long = System.currentTimeMillis()): OrderEntity =
        database.withTransaction {
            val order = orderDao.getById(orderId) ?: error("Order $orderId not found")
            if (order.status == OrderStatus.CANCELLED) return@withTransaction order

            orderDao.updateOrder(order.copy(status = OrderStatus.CANCELLED, updatedAt = now))
            restoreStockForOrder(order, now)
            writeEvent(TransactionType.ORDER_CANCELLED, Money.ZERO, now, order.id, "لغو سفارش ${order.orderNumber}")
            order.copy(status = OrderStatus.CANCELLED, updatedAt = now)
        }

    /** Idempotent stock restoration for a cancelled order (spec §20). */
    private suspend fun restoreStockForOrder(order: OrderEntity, now: Long) {
        val deducted = !hasNoMovements(InventoryReferenceType.ORDER, order.id, InventoryMovementType.SALE)
        val restored = !hasNoMovements(InventoryReferenceType.ORDER, order.id, InventoryMovementType.RETURN)
        if (deducted && !restored) {
            for (item in orderDao.getItems(order.id)) {
                inventoryRepository.applyMovement(
                    productId = item.productId,
                    quantityDelta = item.quantity,
                    movementType = InventoryMovementType.RETURN,
                    referenceType = InventoryReferenceType.ORDER,
                    referenceId = order.id,
                    note = "لغو سفارش ${order.orderNumber}",
                    now = now,
                )
            }
        }
    }

    /**
     * Spec §18: full or partial payment. Overpaying beyond the customer total
     * is rejected; original payment rows are never modified or deleted.
     */
    suspend fun recordPayment(
        orderId: Long,
        amount: Money,
        method: String,
        paymentMethodId: Long? = null,
        reference: String? = null,
        note: String? = null,
        now: Long = System.currentTimeMillis(),
    ): PaymentEntity = database.withTransaction {
        val detailTotal = orderTotal(orderId)
        val remaining = detailTotal - paymentDao.sumPaidForOrder(orderId).let { Money(it) }
        require(amount.isPositive) { "مبلغ پرداخت باید بیشتر از صفر باشد" }
        require(amount <= remaining) {
            "مبلغ پرداخت نمی‌تواند از مانده سفارش (${remaining.toPersianDisplayString()}) بیشتر باشد"
        }
        val id = paymentDao.insert(
            PaymentEntity(orderId = orderId, amount = amount, method = method, paymentMethodId = paymentMethodId, paidAt = now, reference = reference, notes = note),
        )
        writeEvent(TransactionType.PAYMENT_RECEIVED, amount, now, orderId, "دریافت وجه")
        PaymentEntity(orderId = orderId, amount = amount, method = method, paymentMethodId = paymentMethodId, paidAt = now, reference = reference, notes = note).copy(id = id)
    }

    /**
     * Spec §21–§23: full or partial return. Only the returned units restock
     * (one RETURN movement per line, referencing the RETURN id — idempotent).
     * When every ordered unit has been returned, the order becomes RETURNED.
     */
    suspend fun createReturn(
        orderId: Long,
        items: List<ReturnItemDraft>,
        reason: ReturnReason,
        status: ReturnStatus = ReturnStatus.RECEIVED,
        returnShippingCost: Money = Money.ZERO,
        packagingCostLost: Money = Money.ZERO,
        restockedToInventory: Boolean = true,
        now: Long = System.currentTimeMillis(),
    ): OrderReturnEntity = database.withTransaction {
        val order = orderDao.getById(orderId) ?: error("Order $orderId not found")
        val orderItems = orderDao.getItems(orderId)
        require(items.isNotEmpty()) { "حداقل یک کالا برای مرجوعی انتخاب کنید" }

        for (draft in items) {
            val ordered = orderItems.firstOrNull { it.productId == draft.productId }
                ?: error("کالای ${draft.productId} در این سفارش نیست")
            val alreadyReturned = orderReturnDao.sumReturnedQuantity(orderId, draft.productId)
            require(draft.quantity > 0) { "تعداد مرجوعی باید بیشتر از صفر باشد" }
            require(draft.quantity <= ordered.quantity - alreadyReturned) {
                "بیشتر از تعداد سفارش‌شده (${ordered.quantity - alreadyReturned} واحد باقی‌مانده) نمی‌توانید مرجوع کنید"
            }
        }

        val returnId = orderReturnDao.insert(
            OrderReturnEntity(
                orderId = orderId,
                reason = reason,
                status = status,
                returnShippingCost = returnShippingCost,
                packagingCostLost = packagingCostLost,
                revenueReversed = Money.ZERO, // Phase 4 computes the real reversal
                restockedToInventory = restockedToInventory,
                date = now,
                createdAt = now,
            ),
        )
        orderReturnDao.insertItems(
            items.map { OrderReturnItemEntity(returnId = returnId, productId = it.productId, quantity = it.quantity) },
        )

        if (restockedToInventory && hasNoMovements(InventoryReferenceType.ORDER_RETURN, returnId, InventoryMovementType.RETURN)) {
            for (draft in items) {
                inventoryRepository.applyMovement(
                    productId = draft.productId,
                    quantityDelta = draft.quantity,
                    movementType = InventoryMovementType.RETURN,
                    referenceType = InventoryReferenceType.ORDER_RETURN,
                    referenceId = returnId,
                    note = "مرجوعی سفارش ${order.orderNumber}",
                    now = now,
                )
            }
        }

        // Full return → the order itself becomes RETURNED.
        val fullyReturned = orderItems.all { item ->
            orderReturnDao.sumReturnedQuantity(orderId, item.productId) >= item.quantity
        }
        if (fullyReturned && order.status != OrderStatus.CANCELLED) {
            orderDao.updateOrder(order.copy(status = OrderStatus.RETURNED, updatedAt = now))
        }

        val loss = returnShippingCost + packagingCostLost
        if (loss.isPositive) {
            writeEvent(TransactionType.RETURN_CREATED, -loss, now, orderId, "هزینه‌های مرجوعی (ارسال/بسته‌بندی)")
        } else {
            writeEvent(TransactionType.RETURN_CREATED, Money.ZERO, now, orderId, "ثبت مرجوعی")
        }
        OrderReturnEntity(
            id = returnId, orderId = orderId, reason = reason, status = status,
            returnShippingCost = returnShippingCost, packagingCostLost = packagingCostLost,
            restockedToInventory = restockedToInventory, date = now, createdAt = now,
        )
    }

    suspend fun setReturnStatus(returnId: Long, status: ReturnStatus) = database.withTransaction {
        val r = orderReturnDao.observeById(returnId).first() ?: error("Return $returnId not found")
        orderReturnDao.update(r.copy(status = status))
        r.copy(status = status)
    }

    /** Spec §24: refund — always a separate record; payments stay intact. */
    suspend fun createRefund(
        orderId: Long,
        amount: Money,
        method: String,
        reason: String?,
        note: String? = null,
        now: Long = System.currentTimeMillis(),
    ): RefundEntity = database.withTransaction {
        val paid = Money(paymentDao.sumPaidForOrder(orderId))
        val refunded = Money(refundDao.sumRefundedForOrder(orderId))
        require(amount.isPositive) { "مبلغ استرداد باید بیشتر از صفر باشد" }
        require(amount <= paid - refunded) {
            "مبلغ استرداد نمی‌تواند از پرداختی‌های ثبت‌شده بیشتر باشد"
        }
        val id = refundDao.insert(RefundEntity(orderId = orderId, amount = amount, date = now, method = method, reason = reason, note = note))
        writeEvent(TransactionType.REFUND, -amount, now, orderId, "استرداد مبلغ به مشتری")
        RefundEntity(orderId = orderId, amount = amount, date = now, method = method, reason = reason, note = note).copy(id = id)
    }

    // ---------- helpers ----------

    private suspend fun hasNoMovements(referenceType: InventoryReferenceType, referenceId: Long, movementType: InventoryMovementType): Boolean =
        inventoryMovementDao.countByReference(referenceType.name, referenceId, movementType.name) == 0

    private suspend fun orderTotal(orderId: Long): Money {
        val order = orderDao.getById(orderId) ?: error("Order $orderId not found")
        val items = orderDao.getItems(orderId)
        val subtotal = Money.sum(items.map { Money(it.unitSellingPrice.amountInToman * it.quantity - it.discount.amountInToman) }) - order.discount
        val shipping =
            if (order.shippingPaymentType == ShippingPaymentType.CUSTOMER_PREPAID) order.shippingChargedToCustomer
            else Money.ZERO
        return subtotal + shipping
    }

    private suspend fun writeEvent(type: TransactionType, amount: Money, date: Long, orderId: Long, description: String) {
        financialTransactionDao.insert(
            FinancialTransactionEntity(type = type, amount = amount, date = date, orderId = orderId, description = description),
        )
    }
}

private fun NewOrderItem.toEntity(orderId: Long) = OrderItemEntity(
    orderId = orderId,
    productId = productId,
    quantity = quantity,
    unitSellingPrice = unitSellingPrice,
    unitPurchasePrice = unitPurchasePrice,
    discount = discount,
)
