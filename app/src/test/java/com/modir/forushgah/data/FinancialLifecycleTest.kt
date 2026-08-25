package com.modir.forushgah.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.common.isZero
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.entity.CustomerEntity
import com.modir.forushgah.data.local.entity.FinancialTransactionEntity
import com.modir.forushgah.data.local.entity.ProductEntity
import com.modir.forushgah.data.local.entity.SupplierEntity
import com.modir.forushgah.data.repository.InventoryRepository
import com.modir.forushgah.data.repository.NewOrder
import com.modir.forushgah.data.repository.NewOrderItem
import com.modir.forushgah.data.repository.OrderRepository
import com.modir.forushgah.data.repository.ReturnItemDraft
import com.modir.forushgah.domain.model.InsufficientStockException
import com.modir.forushgah.domain.model.InventoryMovementType
import com.modir.forushgah.domain.model.InventoryReferenceType
import com.modir.forushgah.domain.model.OrderKind
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ReturnReason
import com.modir.forushgah.domain.model.ReturnStatus
import com.modir.forushgah.domain.model.TransactionType
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Phase 4.1: the financial lifecycle (scenarios A–N from the phase spec),
 * plus event idempotency, credit consistency, returns and packaging rules —
 * all against a real in-memory Room database.
 */
@RunWith(RobolectricTestRunner::class)
class FinancialLifecycleTest {

    private lateinit var db: AppDatabase
    private lateinit var orderRepository: OrderRepository

    @Before
    fun setup() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        val inventoryRepository = InventoryRepository(db, db.inventoryMovementDao())
        orderRepository = OrderRepository(
            database = db,
            orderDao = db.orderDao(),
            orderReturnDao = db.orderReturnDao(),
            paymentDao = db.paymentDao(),
            refundDao = db.refundDao(),
            customerDao = db.customerDao(),
            supplierDao = db.supplierDao(),
            inventoryMovementDao = db.inventoryMovementDao(),
            financialTransactionDao = db.financialTransactionDao(),
            inventoryRepository = inventoryRepository,
        )
    }

    @After
    fun teardown() {
        db.close()
    }

    // ---------- helpers ----------

    private suspend fun seedCustomer(name: String = "مشتری"): Long =
        db.customerDao().insert(CustomerEntity(name = name, createdAt = 0, updatedAt = 0))

    private suspend fun seedSupplier(name: String = "تأمین‌کننده"): Long =
        db.supplierDao().insert(SupplierEntity(name = name, createdAt = 0, updatedAt = 0))

    private suspend fun seedProduct(
        name: String = "کالا",
        stock: Int = 100,
        sell: Long = 100_000,
        buy: Long = 50_000,
    ): Long = db.productDao().insert(
        ProductEntity(
            name = name, sku = name,
            purchasePrice = Money(buy), sellingPrice = Money(sell),
            stockQuantity = stock, createdAt = 0, updatedAt = 0,
        ),
    )

    private suspend fun stockOf(productId: Long): Int =
        db.productDao().getById(productId)?.stockQuantity ?: -1

    private suspend fun balanceOf(customerId: Long): Money =
        db.customerDao().getById(customerId)!!.balance

    private suspend fun eventsOf(orderId: Long): List<FinancialTransactionEntity> =
        db.financialTransactionDao().getByOrder(orderId)

    private suspend fun eventsOf(orderId: Long, type: TransactionType): List<FinancialTransactionEntity> =
        eventsOf(orderId).filter { it.type == type }

    // ---------- A. cash sale ----------

    @Test
    fun `A cash sale writes SALE and PAYMENT_RECEIVED exactly once and creates no credit`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, items = listOf(NewOrderItem(product, 2, Money(100_000), Money(50_000)))),
        )

        val sales = eventsOf(order.id, TransactionType.SALE)
        assertThat(sales).hasSize(1)
        assertThat(sales.single().amount).isEqualTo(Money(200_000))
        assertThat(sales.single().orderId).isEqualTo(order.id)

        val payments = eventsOf(order.id, TransactionType.PAYMENT_RECEIVED)
        assertThat(payments).hasSize(1)
        assertThat(payments.single().amount).isEqualTo(Money(200_000))
        assertThat(payments.single().paymentId).isNotNull()

        assertThat(eventsOf(order.id, TransactionType.ORDER_CREATED)).hasSize(1)
        // cash sale creates no customer credit, and no packaging cost was set
        assertThat(balanceOf(customer)).isEqualTo(Money.ZERO)
        assertThat(eventsOf(order.id, TransactionType.PACKAGING_EXPENSE)).isEmpty()
    }

    // ---------- B. non-cash sale ----------

    @Test
    fun `B non-cash sale writes SALE without payment and grows customer credit`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 1, Money(200_000), Money(50_000)))),
        )

        assertThat(eventsOf(order.id, TransactionType.SALE).single().amount).isEqualTo(Money(200_000))
        assertThat(eventsOf(order.id, TransactionType.PAYMENT_RECEIVED)).isEmpty()
        assertThat(balanceOf(customer)).isEqualTo(Money(200_000))
    }

    // ---------- C/D. partial → full payment (spec example) ----------

    @Test
    fun `C-D payments decrease credit step by step until zero`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 400, sell = 50_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 400, Money(50_000), Money(10_000)))),
        )
        // Invoice = 20,000,000
        assertThat(balanceOf(customer)).isEqualTo(Money(20_000_000))

        orderRepository.recordPayment(order.id, Money(5_000_000), "نقدی")
        assertThat(balanceOf(customer)).isEqualTo(Money(15_000_000))

        orderRepository.recordPayment(order.id, Money(10_000_000), "نقدی")
        assertThat(balanceOf(customer)).isEqualTo(Money(5_000_000))

        orderRepository.recordPayment(order.id, Money(5_000_000), "نقدی")
        assertThat(balanceOf(customer)).isEqualTo(Money.ZERO)

        // one event per payment, each traceable to its own payment row
        val paymentEvents = eventsOf(order.id, TransactionType.PAYMENT_RECEIVED)
        assertThat(paymentEvents).hasSize(3)
        assertThat(paymentEvents.map { it.paymentId }).doesNotContainDuplicates()
    }

    // ---------- E. refund ----------

    @Test
    fun `E refund adjusts credit back consistently and keeps payment history`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 100, sell = 50_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 100, Money(50_000), Money(10_000)))),
        )
        orderRepository.recordPayment(order.id, Money(3_000_000), "نقدی")
        assertThat(balanceOf(customer)).isEqualTo(Money(2_000_000))

        orderRepository.createRefund(order.id, Money(1_000_000), "کارت", "تست")
        // net paid = 2M → credit back to 3M
        assertThat(balanceOf(customer)).isEqualTo(Money(3_000_000))

        val refundEvents = eventsOf(order.id, TransactionType.REFUND)
        assertThat(refundEvents).hasSize(1)
        assertThat(refundEvents.single().amount).isEqualTo(Money(-1_000_000))
        assertThat(refundEvents.single().refundId).isNotNull()
        // the original payment row survives the refund
        assertThat(db.paymentDao().getForOrder(order.id)).hasSize(1)
    }

    // ---------- F. partial return ----------

    @Test
    fun `F partial return restocks returned units and reverses pro-rata revenue`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(
                customerId = customer, cashPayment = false, orderDiscount = Money(10_000),
                items = listOf(NewOrderItem(product, 4, Money(100_000), Money(50_000), discount = Money(40_000))),
            ),
        )
        // stock 10 − 4 = 6; credit = 400k − 40k line − 10k order = 350k
        assertThat(stockOf(product)).isEqualTo(6)
        assertThat(balanceOf(customer)).isEqualTo(Money(350_000))

        orderRepository.createReturn(order.id, listOf(ReturnItemDraft(product, 2)), ReturnReason.DEFECTIVE)
        assertThat(stockOf(product)).isEqualTo(8)

        // reversed revenue: 2×100k − 20k line share − 5k order share = 175k
        val revenueEvents = eventsOf(order.id, TransactionType.REVENUE_REVERSED)
        assertThat(revenueEvents).hasSize(1)
        assertThat(revenueEvents.single().amount).isEqualTo(Money(-175_000))
        assertThat(revenueEvents.single().returnId).isNotNull()

        // credit: 350k − 175k = 175k
        assertThat(balanceOf(customer)).isEqualTo(Money(175_000))
        // not a full return yet
        assertThat(db.orderDao().getById(order.id)?.status).isNotEqualTo(OrderStatus.RETURNED)
    }

    // ---------- G. full return ----------

    @Test
    fun `G full return marks the order RETURNED and reverses all revenue`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 4, Money(100_000), Money(50_000)))),
        )
        orderRepository.createReturn(order.id, listOf(ReturnItemDraft(product, 4)), ReturnReason.OTHER)

        assertThat(db.orderDao().getById(order.id)?.status).isEqualTo(OrderStatus.RETURNED)
        assertThat(stockOf(product)).isEqualTo(10)
        // credit: 400k − 400k = 0
        assertThat(balanceOf(customer)).isEqualTo(Money.ZERO)
        assertThat(eventsOf(order.id, TransactionType.REVENUE_REVERSED).single().amount).isEqualTo(Money(-400_000))
    }

    // ---------- H. cancellation ----------

    @Test
    fun `H cancellation reverses financial effect exactly once and preserves history`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 2, Money(100_000), Money(50_000)))),
        )
        orderRepository.recordPayment(order.id, Money(100_000), "نقدی")
        // credit: 200k − 100k = 100k
        assertThat(balanceOf(customer)).isEqualTo(Money(100_000))

        orderRepository.cancelOrder(order.id)

        assertThat(db.orderDao().getById(order.id)?.status).isEqualTo(OrderStatus.CANCELLED)
        assertThat(stockOf(product)).isEqualTo(10)
        // the credit contribution of the cancelled order is removed
        assertThat(balanceOf(customer)).isEqualTo(Money.ZERO)
        // payment rows are PRESERVED — cancellation is not a deletion
        assertThat(db.paymentDao().getForOrder(order.id)).hasSize(1)

        // every active non-zero event has exactly one reversal
        val events = eventsOf(order.id)
        val active = events.filter { it.reversalOfId == null && !it.amount.isZero }
        assertThat(active).isNotEmpty()
        for (event in active) {
            val reversals = events.filter { it.reversalOfId == event.id }
            assertThat(reversals).hasSize(1)
            assertThat(reversals.single().type).isEqualTo(event.type)
            assertThat(reversals.single().amount).isEqualTo(-event.amount)
        }
        // the whole order log nets to zero
        assertThat(events.sumOf { it.amount.amountInToman }).isEqualTo(0L)
    }

    // ---------- I. deletion ----------

    @Test
    fun `I deletion preserves history, reverses finance, restores stock once`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = true, items = listOf(NewOrderItem(product, 2, Money(100_000), Money(50_000)))),
        )
        assertThat(stockOf(product)).isEqualTo(8)

        orderRepository.deleteOrder(order.id)

        assertThat(stockOf(product)).isEqualTo(10)
        // soft delete: the row is preserved as DELETED, never CASCADE-deleted
        assertThat(db.orderDao().getById(order.id)?.status).isEqualTo(OrderStatus.DELETED)
        // payment history preserved
        assertThat(db.paymentDao().getForOrder(order.id)).hasSize(1)
        // no orphaned positive events: the log nets to zero
        assertThat(eventsOf(order.id).sumOf { it.amount.amountInToman }).isEqualTo(0L)
        // cash sale → no credit to clear
        assertThat(balanceOf(customer)).isEqualTo(Money.ZERO)
    }

    // ---------- J. edit / replace ----------

    @Test
    fun `J edit preserves old history and never double counts`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 20, sell = 100_000)
        val old = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = true, items = listOf(NewOrderItem(product, 2, Money(100_000), Money(50_000)))),
        )
        // Rubi edit: replace with 3 units of the same product
        val newOrder = orderRepository.replaceOrder(
            old.id,
            NewOrder(customerId = customer, cashPayment = true, items = listOf(NewOrderItem(product, 3, Money(100_000), Money(50_000)))),
        )

        // stock: 20 − 2 (old) + 2 (restored) − 3 (new) = 17
        assertThat(stockOf(product)).isEqualTo(17)
        // old row preserved, soft-deleted, sharing the replacement's number
        val oldRow = db.orderDao().getById(old.id)!!
        assertThat(oldRow.status).isEqualTo(OrderStatus.DELETED)
        assertThat(oldRow.orderNumber).isEqualTo(newOrder.orderNumber)
        // net SALE across old + new = 300k only (no double count)
        val netSale = (eventsOf(old.id) + eventsOf(newOrder.id))
            .filter { it.type == TransactionType.SALE }
            .sumOf { it.amount.amountInToman }
        assertThat(netSale).isEqualTo(300_000L)
    }

    // ---------- K. repeated cancellation ----------

    @Test
    fun `K repeated cancellation is idempotent`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 2, Money(100_000), Money(50_000)))),
        )
        orderRepository.cancelOrder(order.id)
        val afterFirst = eventsOf(order.id)

        orderRepository.cancelOrder(order.id) // second cancel — no-op

        assertThat(eventsOf(order.id)).hasSize(afterFirst.size)
        assertThat(stockOf(product)).isEqualTo(10)
        // exactly one restock movement for the order reference
        assertThat(db.inventoryMovementDao().countByReference(
            InventoryReferenceType.ORDER.name, order.id, InventoryMovementType.RETURN.name,
        )).isEqualTo(1)
    }

    // ---------- L. duplicate payment attempt ----------

    @Test
    fun `L duplicate payment attempt cannot overpay`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 100, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 10, Money(100_000), Money(50_000)))),
        )
        orderRepository.recordPayment(order.id, Money(100_000), "نقدی")
        // 900k remains — a second 1M request must be rejected
        val error = runCatching { orderRepository.recordPayment(order.id, Money(1_000_000), "نقدی") }.exceptionOrNull()
        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)
        assertThat(db.paymentDao().getForOrder(order.id)).hasSize(1)
        assertThat(eventsOf(order.id, TransactionType.PAYMENT_RECEIVED)).hasSize(1)
    }

    // ---------- M. duplicate refund attempt ----------

    @Test
    fun `M duplicate refund request cannot exceed what was paid`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 100, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 10, Money(100_000), Money(50_000)))),
        )
        orderRepository.recordPayment(order.id, Money(1_000_000), "نقدی")
        orderRepository.createRefund(order.id, Money(500_000), "کارت", "تست")
        // refundable = 1M − 500k = 500k
        val error = runCatching { orderRepository.createRefund(order.id, Money(600_000), "کارت", "تست") }.exceptionOrNull()
        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)
        orderRepository.createRefund(order.id, Money(500_000), "کارت", "تست")
        val error2 = runCatching { orderRepository.createRefund(order.id, Money(1), "کارت", "تست") }.exceptionOrNull()
        assertThat(error2).isInstanceOf(IllegalArgumentException::class.java)
        assertThat(db.refundDao().sumRefundedForOrder(order.id)).isEqualTo(1_000_000L)
        assertThat(eventsOf(order.id, TransactionType.REFUND)).hasSize(2)
    }

    // ---------- N. rejected return ----------

    @Test
    fun `N rejected return reverses stock and financial effect exactly once`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 4, Money(100_000), Money(50_000)))),
        )
        val returned = orderRepository.createReturn(order.id, listOf(ReturnItemDraft(product, 2)), ReturnReason.OTHER)
        // stock 6 + 2 = 8; credit 400k − 200k = 200k
        assertThat(stockOf(product)).isEqualTo(8)
        assertThat(balanceOf(customer)).isEqualTo(Money(200_000))

        orderRepository.setReturnStatus(returned.id, ReturnStatus.REJECTED)

        // stock back to the pre-return state; credit restored
        assertThat(stockOf(product)).isEqualTo(6)
        assertThat(balanceOf(customer)).isEqualTo(Money(400_000))
        // the return's active events are each reversed exactly once; net zero
        val returnEvents = eventsOf(order.id).filter { it.returnId == returned.id }
        val active = returnEvents.filter { it.reversalOfId == null && !it.amount.isZero }
        assertThat(active).isNotEmpty()
        for (event in active) {
            assertThat(returnEvents.count { it.reversalOfId == event.id }).isEqualTo(1)
        }
        assertThat(returnEvents.sumOf { it.amount.amountInToman }).isEqualTo(0L)

        // rejecting again is a no-op (REJECTED is terminal) — one reversal movement only
        orderRepository.setReturnStatus(returned.id, ReturnStatus.REJECTED)
        assertThat(stockOf(product)).isEqualTo(6)
        assertThat(db.inventoryMovementDao().countByReference(
            InventoryReferenceType.ORDER_RETURN.name, returned.id, InventoryMovementType.ADJUSTMENT_OUT.name,
        )).isEqualTo(1)
    }

    @Test
    fun `rejected return rolls back when resold units would drive stock negative`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 4, Money(100_000), Money(50_000)))),
        )
        val returned = orderRepository.createReturn(order.id, listOf(ReturnItemDraft(product, 4)), ReturnReason.OTHER)
        assertThat(stockOf(product)).isEqualTo(10)

        // resell the restocked units
        orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = true, items = listOf(NewOrderItem(product, 10, Money(100_000), Money(50_000)))),
        )
        assertThat(stockOf(product)).isEqualTo(0)

        // rejecting now would drive stock below zero → the whole transition
        // must roll back (non-negative stock policy preserved)
        val error = runCatching { orderRepository.setReturnStatus(returned.id, ReturnStatus.REJECTED) }.exceptionOrNull()
        assertThat(error).isInstanceOf(InsufficientStockException::class.java)
        assertThat(db.orderReturnDao().observeById(returned.id).first()?.status).isNotEqualTo(ReturnStatus.REJECTED)
        assertThat(stockOf(product)).isEqualTo(0)
    }

    // ---------- purchase guard ----------

    @Test
    fun `purchase return is rejected safely with no side effects`() = runBlocking {
        val supplier = seedSupplier()
        val product = seedProduct(stock = 5, sell = 100_000, buy = 50_000)
        val order = orderRepository.createOrder(
            NewOrder(supplierId = supplier, kind = OrderKind.PURCHASE, cashPayment = true, items = listOf(NewOrderItem(product, 3, Money(100_000), Money(50_000)))),
        )
        assertThat(stockOf(product)).isEqualTo(8)

        val error = runCatching {
            orderRepository.createReturn(order.id, listOf(ReturnItemDraft(product, 1)), ReturnReason.OTHER)
        }.exceptionOrNull()
        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)

        // nothing happened: stock untouched, no return row, no reversed revenue
        assertThat(stockOf(product)).isEqualTo(8)
        assertThat(db.orderReturnDao().observeAll().first()).isEmpty()
        assertThat(db.orderReturnDao().sumActiveReversedRevenue(order.id)).isEqualTo(0L)
        assertThat(eventsOf(order.id, TransactionType.REVENUE_REVERSED)).isEmpty()
    }

    // ---------- packaging stays optional ----------

    @Test
    fun `packaging cost is optional and only charged when present`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10)
        // default (zero) packaging → no packaging event
        val orderA = orderRepository.createOrder(
            NewOrder(customerId = customer, items = listOf(NewOrderItem(product, 1, Money(100_000), Money(50_000)))),
        )
        assertThat(eventsOf(orderA.id, TransactionType.PACKAGING_EXPENSE)).isEmpty()

        // explicit packaging cost → one traceable expense event
        val orderB = orderRepository.createOrder(
            NewOrder(customerId = customer, packagingCost = Money(25_000), items = listOf(NewOrderItem(product, 1, Money(100_000), Money(50_000)))),
        )
        val packaging = eventsOf(orderB.id, TransactionType.PACKAGING_EXPENSE)
        assertThat(packaging).hasSize(1)
        assertThat(packaging.single().amount).isEqualTo(Money(-25_000))
        assertThat(packaging.single().orderId).isEqualTo(orderB.id)
    }

    // ---------- balance floor ----------

    @Test
    fun `balance never becomes negative even when money goes back on a cash sale`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 100, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = true, items = listOf(NewOrderItem(product, 10, Money(100_000), Money(50_000)))),
        )
        orderRepository.createRefund(order.id, Money(1_000_000), "کارت", "تست")
        // cash sale: no credit was created, so a refund keeps the balance at zero
        assertThat(balanceOf(customer)).isEqualTo(Money.ZERO)
    }

    // ---------- duplicate financial event protection ----------

    @Test
    fun `corrections are written exactly once across cancel then delete`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 10, sell = 100_000)
        val order = orderRepository.createOrder(
            NewOrder(customerId = customer, cashPayment = false, items = listOf(NewOrderItem(product, 2, Money(100_000), Money(50_000)))),
        )
        orderRepository.recordPayment(order.id, Money(100_000), "نقدی")

        orderRepository.cancelOrder(order.id)
        val afterCancel = eventsOf(order.id).size

        orderRepository.deleteOrder(order.id) // second terminal transition
        val afterDelete = eventsOf(order.id)

        // the delete added no new events: the reversal guard skipped every
        // already-reversed event and the marker guard skipped ORDER_CANCELLED
        assertThat(afterDelete).hasSize(afterCancel)
        for ((reversalOfId, count) in afterDelete.groupingBy { it.reversalOfId }.eachCount()) {
            if (reversalOfId != null) assertThat(count).isAtMost(1)
        }
        assertThat(db.orderDao().getById(order.id)?.status).isEqualTo(OrderStatus.DELETED)
        // stock restored exactly once across both transitions
        assertThat(db.inventoryMovementDao().countByReference(
            InventoryReferenceType.ORDER.name, order.id, InventoryMovementType.RETURN.name,
        )).isEqualTo(1)
    }
}
