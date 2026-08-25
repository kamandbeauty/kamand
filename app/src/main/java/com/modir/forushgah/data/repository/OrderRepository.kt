package com.modir.forushgah.data.repository

import androidx.room.withTransaction
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.isPositive
import com.modir.forushgah.core.common.isZero
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
import com.modir.forushgah.data.local.dao.SupplierDao
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
import com.modir.forushgah.domain.model.OrderKind
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ReturnReason
import com.modir.forushgah.domain.model.ReturnStatus
import com.modir.forushgah.domain.model.ShippingPaymentType
import com.modir.forushgah.domain.model.TransactionType
import com.modir.forushgah.domain.usecase.finance.ReturnRevenueCalculator
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

/**
 * One line of a new order (spec §3/§5). Prices are snapshots at order time.
 * [productId] null = free/manual invoice line (Rubi free item) — never touches
 * inventory; [title]/[unit] are the display snapshot (Rubi items are title-based).
 */
data class NewOrderItem(
    val productId: Long? = null,
    val quantity: Int,
    val unitSellingPrice: Money,
    val unitPurchasePrice: Money,
    val discount: Money = Money.ZERO,
    val title: String = "",
    val unit: String = "عدد",
)

/**
 * All inputs for [OrderRepository.createOrder] — validated upstream by
 * `ValidateOrderUseCase` before reaching the repository.
 *
 * Phase 3.1 (Rubi invoice semantics):
 * - [kind] SALES → customer + stock OUT (SALE); PURCHASE → supplier + stock IN (PURCHASE)
 * - [cashPayment] (Rubi paymentType cash/non_cash): cash writes a full Payment row;
 *   non-cash leaves the remaining as credit (grows the customer balance)
 * - [orderNumber]: user value (Rubi prefill/edit); null → next sequential number
 * - [shippingChargedToCustomer] (Rubi shippingFee) is added to the customer total
 */
data class NewOrder(
    val customerId: Long? = null,
    val supplierId: Long? = null,
    val kind: OrderKind = OrderKind.SALES,
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
    val cashPayment: Boolean = true,
    val notes: String? = null,
    val orderNumber: String? = null,
    val orderDate: Long = System.currentTimeMillis(),
)

/** One line of a return draft (spec §21). */
data class ReturnItemDraft(val productId: Long, val quantity: Int)

data class OrderDetail(
    val order: OrderEntity,
    val items: List<OrderItemWithProduct>,
    val customerName: String?,
    val customerMobile: String?,
    /** Phase 3.1: supplier name for purchase invoices. */
    val supplierName: String? = null,
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
 * Order lifecycle (spec §19–§24) — the operational core the financial engine
 * builds on.
 *
 * Every state change is ONE Room transaction (order + items + inventory
 * movements + financial events commit together or not at all). Inventory is
 * mutated only through [InventoryRepository]; movements are keyed by
 * (referenceType, referenceId, movementType) and guarded by
 * `countByReference`, so the same order can never deduct or restore stock
 * twice — even if the UI double-fires (spec §19 idempotency).
 *
 * Phase 4.1 financial core:
 * - Every financial effect writes a traceable [FinancialTransactionEntity]
 *   (SALE / PAYMENT_RECEIVED / REFUND / RETURN_CREATED / REVENUE_REVERSED /
 *   PACKAGING_EXPENSE + zero-amount lifecycle markers), each guarded by a
 *   deterministic idempotency check — a repeated operation can never write
 *   the same financial effect twice.
 * - Cancellation / deletion / edit are business events: the row and its
 *   payment/refund/return history are PRESERVED, the financial effect is
 *   reversed exactly once (correction events with `reversalOfId`), and stock
 *   is restored exactly once. Deletion is a SOFT delete (status DELETED) so
 *   CASCADE can never erase financial history.
 * - Customer credit («بستانکی») is recomputed exactly from the financial
 *   state ([CustomerDao.sumActiveCredit]) on every money-affecting
 *   operation — payments and refunds move it, and it never goes negative.
 */
@Singleton
class OrderRepository @Inject constructor(
    private val database: AppDatabase,
    private val orderDao: OrderDao,
    private val orderReturnDao: OrderReturnDao,
    private val paymentDao: PaymentDao,
    private val refundDao: RefundDao,
    private val customerDao: CustomerDao,
    private val supplierDao: SupplierDao,
    private val inventoryMovementDao: InventoryMovementDao,
    private val financialTransactionDao: FinancialTransactionDao,
    private val inventoryRepository: InventoryRepository,
) {

    // ---------- read side ----------

    /** Rubi create-screen prefill: the next sequential invoice number. */
    suspend fun nextNumberPreview(): String = orderDao.nextOrderNumber().toString()

    /**
     * Phase 3.1 (Rubi «ویرایش»): load an invoice back into its create form.
     */
    suspend fun loadEditable(orderId: Long): NewOrder? {
        val order = orderDao.getById(orderId) ?: return null
        val items = orderDao.getItems(orderId)
        return NewOrder(
            customerId = order.customerId,
            supplierId = order.supplierId,
            kind = order.kind,
            items = items.map {
                NewOrderItem(
                    productId = it.productId,
                    quantity = it.quantity,
                    unitSellingPrice = it.unitSellingPrice,
                    unitPurchasePrice = it.unitPurchasePrice,
                    discount = it.discount,
                    title = it.title,
                    unit = it.unit,
                )
            },
            orderDiscount = order.discount,
            salesChannelId = order.salesChannelId,
            shippingProviderId = order.shippingProviderId,
            shippingPaymentType = order.shippingPaymentType,
            shippingChargedToCustomer = order.shippingChargedToCustomer,
            actualShippingCost = order.actualShippingCost,
            packagingCost = order.packagingCost,
            cashPayment = order.isCashPayment,
            notes = order.notes,
            orderNumber = order.orderNumber,
            orderDate = order.orderDate,
        )
    }

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
            val supplier = order.supplierId?.let { supplierDao.getById(it) }
            val returnItems = returns.flatMap { r -> orderReturnDao.getItems(r.id) }
            OrderDetail(
                order = order,
                items = items,
                customerName = customer?.name,
                customerMobile = customer?.mobile,
                supplierName = supplier?.name,
                payments = payments,
                refunds = refunds,
                returns = returns,
                returnItems = returnItems,
            )
        }

    // ---------- write side ----------

    /**
     * Spec §3/§19/§26 + Phase 3.1 (Rubi invoice creation): create order +
     * items + inventory movements + payment/credit + financial events, atomically.
     *
     * - SALES: one SALE -qty movement per product line; fails (rolls back
     *   everything) if any line would drive stock negative — overselling is
     *   impossible by construction, never silent.
     * - PURCHASE: one PURCHASE +qty movement per product line (stock in).
     * - Free lines (productId = null) never touch inventory (Rubi free items).
     * - Cash payment writes a full Payment row (Rubi paymentType=cash → paid).
     * - Non-cash sales grow the customer credit (recomputed exactly, Phase 4.1).
     * - Phase 4.1 events: SALE (real revenue, cash or credit),
     *   PAYMENT_RECEIVED (cash), PACKAGING_EXPENSE (only when the invoice
     *   actually carries a packaging cost — it stays optional), and the
     *   zero-amount ORDER_CREATED marker. Every event is idempotency-guarded.
     */
    suspend fun createOrder(draft: NewOrder): OrderEntity = database.withTransaction {
        val now = draft.orderDate
        val isPurchase = draft.kind == OrderKind.PURCHASE
        if (isPurchase) require(draft.supplierId != null) { "تأمین‌کننده فاکتور خرید را مشخص کنید" }
        else require(draft.customerId != null) { "مشتری فاکتور فروش را مشخص کنید" }
        require(draft.items.isNotEmpty()) { "حداقل یک قلم کالا اضافه کنید" }

        val orderNumber = draft.orderNumber?.trim()?.takeIf { it.isNotEmpty() }
            ?: orderDao.nextOrderNumber().toString()

        val temp = OrderEntity(
            orderNumber = orderNumber,
            customerId = draft.customerId,
            supplierId = draft.supplierId,
            kind = draft.kind,
            isCashPayment = draft.cashPayment,
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
        orderDao.insertItems(draft.items.map { it.toEntity(orderId) })

        // Inventory (spec §19): SALES deduct, PURCHASE adds. Guarded — a second
        // call for the same order never moves stock again (idempotency).
        val productLines = draft.items.filter { it.productId != null }
        if (isPurchase) {
            if (hasNoMovements(InventoryReferenceType.ORDER, orderId, InventoryMovementType.PURCHASE)) {
                for (item in productLines) {
                    inventoryRepository.applyMovement(
                        productId = item.productId!!,
                        quantityDelta = item.quantity,
                        movementType = InventoryMovementType.PURCHASE,
                        referenceType = InventoryReferenceType.ORDER,
                        referenceId = orderId,
                        note = "فاکتور خرید $orderNumber",
                        now = now,
                    )
                }
            }
        } else if (hasNoMovements(InventoryReferenceType.ORDER, orderId, InventoryMovementType.SALE)) {
            for (item in productLines) {
                inventoryRepository.applyMovement(
                    productId = item.productId!!,
                    quantityDelta = -item.quantity,
                    movementType = InventoryMovementType.SALE,
                    referenceType = InventoryReferenceType.ORDER,
                    referenceId = orderId,
                    note = "فاکتور فروش $orderNumber",
                    now = now,
                )
            }
        }

        // Financial state (Phase 4.1).
        val subtotal = Money.sum(draft.items.map {
            Money(it.unitSellingPrice.amountInToman * it.quantity - it.discount.amountInToman)
        }) - draft.orderDiscount
        val total = (subtotal + draft.shippingChargedToCustomer).coerceAtLeastZero()

        if (draft.cashPayment) {
            if (total.isPositive) {
                val paymentId = paymentDao.insert(
                    PaymentEntity(
                        orderId = orderId,
                        amount = total,
                        method = draft.paymentMethodLabel,
                        paymentMethodId = draft.paymentMethodId,
                        paidAt = now,
                        reference = null,
                        notes = "پرداخت نقدی هنگام صدور فاکتور",
                    ),
                )
                writeEventIfAbsent(
                    type = TransactionType.PAYMENT_RECEIVED,
                    amount = total,
                    date = now,
                    orderId = orderId,
                    customerId = draft.customerId,
                    supplierId = draft.supplierId,
                    paymentId = paymentId,
                    description = "دریافت وجه نقدی",
                )
            }
        }

        // A real sale recognizes revenue at creation — cash or credit.
        // (A purchase invoice is a buy from a supplier, not store revenue.)
        if (!isPurchase && total.isPositive) {
            writeEventIfAbsent(
                type = TransactionType.SALE,
                amount = total,
                date = now,
                orderId = orderId,
                customerId = draft.customerId,
                supplierId = draft.supplierId,
                description = "ثبت فروش فاکتور $orderNumber",
            )
        }

        // Packaging cost stays OPTIONAL (business rule): the event is written
        // only when this invoice actually carries a packaging cost. Bulk
        // packaging purchases are store EXPENSES (later phase), never an
        // automatic per-invoice charge.
        if (draft.packagingCost.isPositive) {
            writeEventIfAbsent(
                type = TransactionType.PACKAGING_EXPENSE,
                amount = -draft.packagingCost,
                date = now,
                orderId = orderId,
                customerId = draft.customerId,
                supplierId = draft.supplierId,
                description = "هزینه بسته‌بندی فاکتور $orderNumber",
            )
        }

        writeEventIfAbsent(
            type = TransactionType.ORDER_CREATED,
            amount = Money.ZERO,
            date = now,
            orderId = orderId,
            customerId = draft.customerId,
            supplierId = draft.supplierId,
            description = "ثبت ${if (isPurchase) "فاکتور خرید" else "فاکتور فروش"} $orderNumber",
        )

        // Customer credit (non-cash sales): recomputed exactly from the
        // financial state — the new order's total enters the credit sum.
        draft.customerId?.let { recalcCustomerBalance(it, now) }

        temp.copy(id = orderId)
    }

    /**
     * Status transition. Cancellation always goes through the cancel logic
     * (stock restoration + financial correction) so the status menu and the
     * cancel button can never diverge; cancelling a terminal order is a
     * no-op. DELETED is a system state — routed through the safe delete path
     * (never a bare status write).
     */
    suspend fun updateStatus(orderId: Long, status: OrderStatus, now: Long = System.currentTimeMillis()): OrderEntity =
        database.withTransaction {
            val order = orderDao.getById(orderId) ?: error("Order $orderId not found")
            if (order.status == status) return@withTransaction order
            when (status) {
                OrderStatus.CANCELLED -> {
                    if (order.status == OrderStatus.CANCELLED || order.status == OrderStatus.DELETED ||
                        order.status == OrderStatus.RETURNED
                    ) {
                        return@withTransaction order
                    }
                    applyCancellation(order, now)
                }
                OrderStatus.DELETED -> {
                    if (order.status != OrderStatus.DELETED) applyDelete(order, now)
                    order.copy(status = OrderStatus.DELETED, updatedAt = now)
                }
                else -> {
                    // Phase 4.2: terminal (closed) orders can never be
                    // reopened into an active state — the status menu hides
                    // these targets, and the repository rejects them too, so
                    // the protection does not rely on the UI.
                    require(!isClosedForReactivation(order.status)) {
                        "این فاکتور «${terminalLabel(order.status)}» است و دوباره قابل فعال‌سازی نیست"
                    }
                    orderDao.updateOrder(order.copy(status = status, updatedAt = now))
                    order.copy(status = status, updatedAt = now)
                }
            }
        }

    /**
     * Spec §20 + Phase 4.1: cancelling an order that already deducted stock
     * restores it (idempotent), and the order's financial effect is reversed
     * exactly once (correction events). Payments/refunds/returns are PRESERVED
     * — cancellation is a business event, never a physical deletion.
     */
    suspend fun cancelOrder(orderId: Long, now: Long = System.currentTimeMillis()): OrderEntity =
        database.withTransaction {
            val order = orderDao.getById(orderId) ?: error("Order $orderId not found")
            if (order.status == OrderStatus.CANCELLED || order.status == OrderStatus.DELETED) {
                return@withTransaction order
            }
            applyCancellation(order, now)
        }

    private suspend fun applyCancellation(order: OrderEntity, now: Long): OrderEntity {
        orderDao.updateOrder(order.copy(status = OrderStatus.CANCELLED, updatedAt = now))
        restoreStockForOrder(order, now)
        reverseOrderFinancialEvents(order, now, "لغو سفارش")
        order.customerId?.let { recalcCustomerBalance(it, now) }
        writeEventIfAbsent(
            type = TransactionType.ORDER_CANCELLED,
            amount = Money.ZERO,
            date = now,
            orderId = order.id,
            customerId = order.customerId,
            supplierId = order.supplierId,
            description = "لغو سفارش ${order.orderNumber}",
        )
        return order.copy(status = OrderStatus.CANCELLED, updatedAt = now)
    }

    /**
     * Phase 4.1 (Rubi list action «حذف فاکتور»): SOFT delete. The order row
     * and ALL its financial history (payments/refunds/returns/events) are
     * preserved — Room CASCADE is never relied on for financial history.
     * Stock is restored exactly once and the financial effect is reversed
     * exactly once; repeat calls are no-ops. The row becomes DELETED (hidden
     * from regular lists, available in the Deleted/Cancelled section).
     */
    suspend fun deleteOrder(orderId: Long, now: Long = System.currentTimeMillis()) =
        database.withTransaction {
            val order = orderDao.getById(orderId) ?: error("Order $orderId not found")
            if (order.status == OrderStatus.DELETED) return@withTransaction
            applyDelete(order, now)
        }

    private suspend fun applyDelete(order: OrderEntity, now: Long, reason: String = "حذف فاکتور") {
        orderDao.updateOrder(order.copy(status = OrderStatus.DELETED, updatedAt = now))
        restoreStockForOrder(order, now)
        reverseOrderFinancialEvents(order, now, reason)
        order.customerId?.let { recalcCustomerBalance(it, now) }
        writeEventIfAbsent(
            type = TransactionType.ORDER_CANCELLED,
            amount = Money.ZERO,
            date = now,
            orderId = order.id,
            customerId = order.customerId,
            supplierId = order.supplierId,
            description = "$reason ${order.orderNumber}",
        )
    }

    /**
     * Idempotent stock reversal for a cancelled/deleted/replaced order
     * (spec §20). Restores only the units that were NOT already brought back
     * by active (non-rejected) returns — those restocks are recorded under
     * the RETURN id and must not be duplicated ("reversed exactly once").
     * SALES orders: SALE is reversed by RETURN. PURCHASE orders: the PURCHASE
     * is reversed by ADJUSTMENT_OUT (the bought units are no longer here).
     */
    private suspend fun restoreStockForOrder(order: OrderEntity, now: Long) {
        if (order.kind == OrderKind.PURCHASE) {
            val added = !hasNoMovements(InventoryReferenceType.ORDER, order.id, InventoryMovementType.PURCHASE)
            val reversed = !hasNoMovements(InventoryReferenceType.ORDER, order.id, InventoryMovementType.ADJUSTMENT_OUT)
            if (added && !reversed) {
                for (item in orderDao.getItems(order.id)) {
                    if (item.productId == null) continue
                    inventoryRepository.applyMovement(
                        productId = item.productId,
                        quantityDelta = -item.quantity,
                        movementType = InventoryMovementType.ADJUSTMENT_OUT,
                        referenceType = InventoryReferenceType.ORDER,
                        referenceId = order.id,
                        note = "لغو فاکتور خرید ${order.orderNumber}",
                        now = now,
                    )
                }
            }
            return
        }
        val deducted = !hasNoMovements(InventoryReferenceType.ORDER, order.id, InventoryMovementType.SALE)
        val restored = !hasNoMovements(InventoryReferenceType.ORDER, order.id, InventoryMovementType.RETURN)
        if (deducted && !restored) {
            for (item in orderDao.getItems(order.id)) {
                if (item.productId == null) continue
                // Units already brought back by active returns are excluded —
                // their restock movement exists under the RETURN id.
                val returnedActive = orderReturnDao.sumReturnedQuantity(order.id, item.productId)
                val toRestore = (item.quantity - returnedActive).coerceAtLeast(0)
                if (toRestore > 0) {
                    inventoryRepository.applyMovement(
                        productId = item.productId,
                        quantityDelta = toRestore,
                        movementType = InventoryMovementType.RETURN,
                        referenceType = InventoryReferenceType.ORDER,
                        referenceId = order.id,
                        note = "لغو/حذف سفارش ${order.orderNumber}",
                        now = now,
                    )
                }
            }
        }
    }

    /**
     * Spec §18: full or partial payment. Overpaying beyond the customer total
     * is rejected; original payment rows are never modified or deleted.
     * Phase 4.1: the event carries the paymentId (traceable, one event per
     * payment row) and the customer credit is recomputed exactly.
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
        val order = orderDao.getById(orderId) ?: error("Order $orderId not found")
        require(!isTerminal(order.status)) { "این فاکتور ${terminalLabel(order.status)} است" }
        val detailTotal = orderTotal(orderId)
        val remaining = detailTotal - paymentDao.sumPaidForOrder(orderId).let { Money(it) }
        require(amount.isPositive) { "مبلغ پرداخت باید بیشتر از صفر باشد" }
        require(amount <= remaining) {
            "مبلغ پرداخت نمی‌تواند از مانده سفارش (${remaining.toPersianDisplayString()}) بیشتر باشد"
        }
        val id = paymentDao.insert(
            PaymentEntity(orderId = orderId, amount = amount, method = method, paymentMethodId = paymentMethodId, paidAt = now, reference = reference, notes = note),
        )
        writeEventIfAbsent(
            type = TransactionType.PAYMENT_RECEIVED,
            amount = amount,
            date = now,
            orderId = orderId,
            customerId = order.customerId,
            supplierId = order.supplierId,
            paymentId = id,
            description = "دریافت وجه",
        )
        order.customerId?.let { recalcCustomerBalance(it, now) }
        PaymentEntity(orderId = orderId, amount = amount, method = method, paymentMethodId = paymentMethodId, paidAt = now, reference = reference, notes = note).copy(id = id)
    }

    /**
     * Spec §21–§23 + Phase 4.1: full or partial return. Only the returned
     * units restock (one RETURN movement per line, referencing the RETURN id
     * — idempotent). When every ordered unit has been returned, the order
     * becomes RETURNED.
     *
     * Phase 4.1:
     * - a PURCHASE invoice is REJECTED — it must never use the sales-return
     *   financial flow (purchase returns are a later phase);
     * - the real reversed revenue is computed from historical line price
     *   snapshots with pro-rata discount allocation (no longer zero) and
     *   recorded as a REVENUE_REVERSED event;
     * - the return cost is a traceable RETURN_CREATED event;
     * - the customer credit is recomputed exactly.
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
        require(order.kind != OrderKind.PURCHASE) {
            "مرجوعی فاکتور خرید در این نسخه پشتیبانی نمی‌شود"
        }
        require(!isTerminal(order.status)) { "این فاکتور ${terminalLabel(order.status)} است" }
        val orderItems = orderDao.getItems(orderId)
        require(items.isNotEmpty()) { "حداقل یک کالا برای مرجوعی انتخاب کنید" }

        for (draft in items) {
            val ordered = orderItems.firstOrNull { it.productId == draft.productId }
                ?: error("کالای ${draft.productId} در این سفارش نیست")
            val alreadyReturned = orderReturnDao.sumReturnedQuantity(orderId, draft.productId!!)
            require(draft.quantity > 0) { "تعداد مرجوعی باید بیشتر از صفر باشد" }
            require(draft.quantity <= ordered.quantity - alreadyReturned) {
                "بیشتر از تعداد سفارش‌شده (${ordered.quantity - alreadyReturned} واحد باقی‌مانده) نمی‌توانید مرجوع کنید"
            }
        }

        val revenueReversed = ReturnRevenueCalculator.reversedRevenue(
            orderedLines = orderItems.filter { it.productId != null }.map {
                ReturnRevenueCalculator.OrderedLine(
                    productId = it.productId!!,
                    quantity = it.quantity,
                    unitSellingPrice = it.unitSellingPrice,
                    discount = it.discount,
                )
            },
            orderDiscount = order.discount,
            returned = items.map { ReturnRevenueCalculator.ReturnedLine(it.productId, it.quantity) },
        )

        val returnId = orderReturnDao.insert(
            OrderReturnEntity(
                orderId = orderId,
                reason = reason,
                status = status,
                returnShippingCost = returnShippingCost,
                packagingCostLost = packagingCostLost,
                revenueReversed = revenueReversed,
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

        // Full return → the order itself becomes RETURNED (free lines ignored).
        val trackedItems = orderItems.filter { it.productId != null }
        val fullyReturned = trackedItems.isNotEmpty() && trackedItems.all { item ->
            orderReturnDao.sumReturnedQuantity(orderId, item.productId!!) >= item.quantity
        }
        if (fullyReturned && order.status != OrderStatus.CANCELLED) {
            orderDao.updateOrder(order.copy(status = OrderStatus.RETURNED, updatedAt = now))
        }

        val loss = returnShippingCost + packagingCostLost
        writeEventIfAbsent(
            type = TransactionType.RETURN_CREATED,
            amount = -loss,
            date = now,
            orderId = orderId,
            customerId = order.customerId,
            returnId = returnId,
            description = if (loss.isPositive) "هزینه‌های مرجوعی (ارسال/بسته‌بندی)" else "ثبت مرجوعی",
        )
        if (revenueReversed.isPositive) {
            writeEventIfAbsent(
                type = TransactionType.REVENUE_REVERSED,
                amount = -revenueReversed,
                date = now,
                orderId = orderId,
                customerId = order.customerId,
                returnId = returnId,
                description = "کاهش فروش به دلیل مرجوعی",
            )
        }

        order.customerId?.let { recalcCustomerBalance(it, now) }

        OrderReturnEntity(
            id = returnId, orderId = orderId, reason = reason, status = status,
            returnShippingCost = returnShippingCost, packagingCostLost = packagingCostLost,
            revenueReversed = revenueReversed,
            restockedToInventory = restockedToInventory, date = now, createdAt = now,
        )
    }

    /**
     * Phase 4.1: return lifecycle.
     * - non-rejection transitions: plain status update (as before);
     * - → REJECTED: the return's stock restock is reversed (idempotent
     *   ADJUSTMENT_OUT movement) and its financial events are reversed
     *   exactly once; the customer credit is recomputed. REJECTED is
     *   terminal — re-approving a rejected return is refused (it would
     *   double the restock). If the restock reversal would drive stock
     *   negative (the units were resold), the whole transition rolls back
     *   and the return stays in its previous state.
     */
    suspend fun setReturnStatus(returnId: Long, status: ReturnStatus, now: Long = System.currentTimeMillis()) =
        database.withTransaction {
            val r = orderReturnDao.observeById(returnId).first() ?: error("Return $returnId not found")
            if (r.status == status) return@withTransaction r
            if (r.status == ReturnStatus.REJECTED) return@withTransaction r
            if (status != ReturnStatus.REJECTED) {
                orderReturnDao.update(r.copy(status = status))
                return@withTransaction r.copy(status = status)
            }

            orderReturnDao.update(r.copy(status = ReturnStatus.REJECTED))

            if (r.restockedToInventory) {
                val returnItems = orderReturnDao.getItems(r.id)
                if (returnItems.isNotEmpty() &&
                    inventoryMovementDao.countByReference(
                        InventoryReferenceType.ORDER_RETURN.name, r.id, InventoryMovementType.ADJUSTMENT_OUT.name,
                    ) == 0
                ) {
                    for (item in returnItems) {
                        inventoryRepository.applyMovement(
                            productId = item.productId,
                            quantityDelta = -item.quantity,
                            movementType = InventoryMovementType.ADJUSTMENT_OUT,
                            referenceType = InventoryReferenceType.ORDER_RETURN,
                            referenceId = r.id,
                            note = "رد مرجوعی",
                            now = now,
                        )
                    }
                }
            }

            for (event in financialTransactionDao.getByReturn(r.id)) {
                if (event.amount.isZero) continue
                if (event.reversalOfId != null) continue
                writeEventIfAbsent(
                    type = event.type,
                    amount = -event.amount,
                    date = now,
                    orderId = event.orderId,
                    customerId = event.customerId,
                    returnId = event.returnId,
                    reversalOfId = event.id,
                    description = "رد مرجوعی — اصلاح مالی",
                )
            }

            orderDao.getById(r.orderId)?.customerId?.let { recalcCustomerBalance(it, now) }

            r.copy(status = ReturnStatus.REJECTED)
        }

    /**
     * Phase 3.1 (Rubi list action «کپی فاکتور»): duplicates the invoice under
     * the next sequential number. A copy is a real new invoice, so inventory
     * is affected again (a copied sales invoice deducts stock; an oversell
     * fails the copy with a clear error instead of corrupting stock).
     */
    suspend fun copyOrder(sourceOrderId: Long, now: Long = System.currentTimeMillis()): OrderEntity =
        database.withTransaction {
            val source = orderDao.getById(sourceOrderId) ?: error("Order $sourceOrderId not found")
            val items = orderDao.getItems(sourceOrderId).map {
                NewOrderItem(
                    productId = it.productId,
                    quantity = it.quantity,
                    unitSellingPrice = it.unitSellingPrice,
                    unitPurchasePrice = it.unitPurchasePrice,
                    discount = it.discount,
                    title = it.title,
                    unit = it.unit,
                )
            }
            val sourceTotal = orderTotal(sourceOrderId)
            val sourcePaid = Money(paymentDao.sumPaidForOrder(sourceOrderId))
            createOrder(
                NewOrder(
                    customerId = source.customerId,
                    supplierId = source.supplierId,
                    kind = source.kind,
                    items = items,
                    orderDiscount = source.discount,
                    salesChannelId = source.salesChannelId,
                    paymentMethodId = source.paymentMethodId,
                    shippingProviderId = source.shippingProviderId,
                    shippingPaymentType = source.shippingPaymentType,
                    shippingChargedToCustomer = source.shippingChargedToCustomer,
                    actualShippingCost = source.actualShippingCost,
                    packagingCost = source.packagingCost,
                    cashPayment = sourcePaid >= sourceTotal,
                    notes = source.notes,
                    orderDate = now,
                ),
            )
        }

    /**
     * Phase 3.1 (Rubi «ویرایش فاکتور»): re-saves the invoice. Phase 4.1: the
     * old invoice is NOT hard-deleted — its financial history is preserved
     * (soft delete) and its financial effect reversed, so reports represent
     * reality and never double-count old + new state. The replacement is a
     * new order (new id → fresh idempotency guards, fresh events) under the
     * SAME number (the orderNumber index is non-unique for this reason).
     */
    suspend fun replaceOrder(orderId: Long, draft: NewOrder, now: Long = System.currentTimeMillis()): OrderEntity =
        database.withTransaction {
            val old = orderDao.getById(orderId) ?: error("Order $orderId not found")
            if (old.status != OrderStatus.DELETED) {
                applyDelete(old, now, reason = "ویرایش فاکتور")
            }
            createOrder(
                draft.copy(orderNumber = draft.orderNumber?.trim()?.ifEmpty { old.orderNumber } ?: old.orderNumber),
            )
        }

    /** Spec §24: refund — always a separate record; payments stay intact.
     * Phase 4.1: the event carries the refundId (traceable, one event per
     * refund row) and the customer credit is recomputed exactly.
     */
    suspend fun createRefund(
        orderId: Long,
        amount: Money,
        method: String,
        reason: String?,
        note: String? = null,
        now: Long = System.currentTimeMillis(),
    ): RefundEntity = database.withTransaction {
        val order = orderDao.getById(orderId) ?: error("Order $orderId not found")
        require(!isTerminal(order.status)) { "این فاکتور ${terminalLabel(order.status)} است" }
        val paid = Money(paymentDao.sumPaidForOrder(orderId))
        val refunded = Money(refundDao.sumRefundedForOrder(orderId))
        require(amount.isPositive) { "مبلغ استرداد باید بیشتر از صفر باشد" }
        require(amount <= paid - refunded) {
            "مبلغ استرداد نمی‌تواند از پرداختی‌های ثبت‌شده بیشتر باشد"
        }
        val id = refundDao.insert(RefundEntity(orderId = orderId, amount = amount, date = now, method = method, reason = reason, note = note))
        writeEventIfAbsent(
            type = TransactionType.REFUND,
            amount = -amount,
            date = now,
            orderId = orderId,
            customerId = order.customerId,
            supplierId = order.supplierId,
            refundId = id,
            description = "استرداد مبلغ به مشتری",
        )
        order.customerId?.let { recalcCustomerBalance(it, now) }
        RefundEntity(orderId = orderId, amount = amount, date = now, method = method, reason = reason, note = note).copy(id = id)
    }

    // ---------- Phase 4.1 financial helpers ----------

    /**
     * Appends a financial event with a deterministic idempotency guard, so a
     * repeated operation can never write the same financial effect twice:
     * - reversal events: at most one reversal per original event (reversalOfId)
     * - payment events:  one per payment row (paymentId + type)
     * - refund events:   one per refund row (refundId + type)
     * - return events:   one per return + type (returnId + type)
     * - order events:    one per order + type (orderId + type)
     */
    private suspend fun writeEventIfAbsent(
        type: TransactionType,
        amount: Money,
        date: Long,
        orderId: Long?,
        customerId: Long? = null,
        supplierId: Long? = null,
        paymentId: Long? = null,
        refundId: Long? = null,
        returnId: Long? = null,
        referenceType: String? = null,
        referenceId: Long? = null,
        reversalOfId: Long? = null,
        description: String,
    ) {
        val alreadyWritten = when {
            reversalOfId != null -> financialTransactionDao.countReversalsOf(reversalOfId)
            paymentId != null -> financialTransactionDao.countByPaymentAndType(paymentId, type.name)
            refundId != null -> financialTransactionDao.countByRefundAndType(refundId, type.name)
            returnId != null -> financialTransactionDao.countByReturnAndType(returnId, type.name)
            else -> financialTransactionDao.countByOrderAndType(orderId ?: 0L, type.name)
        }
        if (alreadyWritten > 0) return
        financialTransactionDao.insert(
            FinancialTransactionEntity(
                type = type,
                amount = amount,
                date = date,
                orderId = orderId,
                customerId = customerId,
                supplierId = supplierId,
                paymentId = paymentId,
                refundId = refundId,
                returnId = returnId,
                referenceType = referenceType,
                referenceId = referenceId,
                reversalOfId = reversalOfId,
                description = description,
            ),
        )
    }

    /**
     * Reverses every ACTIVE financial event of the order, exactly once per
     * event. Each correction is a NEW event (same type, negated amount,
     * reversalOfId) — history is never mutated or deleted. Zero-amount
     * markers and already-reversed events are skipped, so repeat corrections
     * (cancel → delete, repeated calls) are no-ops.
     */
    private suspend fun reverseOrderFinancialEvents(order: OrderEntity, now: Long, reason: String) {
        for (event in financialTransactionDao.getByOrder(order.id)) {
            if (event.amount.isZero) continue
            if (event.reversalOfId != null) continue // never reverse a reversal
            writeEventIfAbsent(
                type = event.type,
                amount = -event.amount,
                date = now,
                orderId = event.orderId ?: order.id,
                customerId = event.customerId,
                supplierId = event.supplierId,
                paymentId = event.paymentId,
                refundId = event.refundId,
                returnId = event.returnId,
                referenceType = event.referenceType,
                referenceId = event.referenceId,
                reversalOfId = event.id,
                description = "$reason — اصلاح مالی",
            )
        }
    }

    /**
     * Recomputes a customer's outstanding credit EXACTLY from the financial
     * state (never incrementally) — payment totals, receivable, customer
     * balance and the event log always agree. Never goes negative.
     */
    private suspend fun recalcCustomerBalance(customerId: Long, now: Long) {
        val customer = customerDao.getById(customerId) ?: return
        val outstanding = Money(customerDao.sumActiveCredit(customerId)).coerceAtLeastZero()
        if (customer.balance != outstanding) {
            customerDao.update(customer.copy(balance = outstanding, updatedAt = now))
        }
    }

    private fun isTerminal(status: OrderStatus): Boolean =
        status == OrderStatus.CANCELLED || status == OrderStatus.DELETED

    /**
     * Phase 4.2: terminal states that must never be reopened into an active
     * status through the normal status transition. [isTerminal] is the
     * payment/return/refund guard (Phase 4.1); this one additionally closes
     * RETURNED for reactivation — a fully returned invoice is done.
     * (CANCELLED → DELETED remains a valid terminal-to-terminal move.)
     */
    private fun isClosedForReactivation(status: OrderStatus): Boolean =
        status == OrderStatus.CANCELLED ||
            status == OrderStatus.DELETED ||
            status == OrderStatus.RETURNED

    private fun terminalLabel(status: OrderStatus): String = when (status) {
        OrderStatus.DELETED -> "حذف"
        OrderStatus.RETURNED -> "مرجوع شده"
        else -> "لغو"
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
}

private fun NewOrderItem.toEntity(orderId: Long) = OrderItemEntity(
    orderId = orderId,
    productId = productId,
    quantity = quantity,
    unitSellingPrice = unitSellingPrice,
    unitPurchasePrice = unitPurchasePrice,
    discount = discount,
    title = title,
    unit = unit,
)
