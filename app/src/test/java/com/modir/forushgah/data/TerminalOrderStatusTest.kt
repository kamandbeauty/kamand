package com.modir.forushgah.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.entity.CustomerEntity
import com.modir.forushgah.data.local.entity.ProductEntity
import com.modir.forushgah.data.repository.InventoryRepository
import com.modir.forushgah.data.repository.NewOrder
import com.modir.forushgah.data.repository.NewOrderItem
import com.modir.forushgah.data.repository.OrderRepository
import com.modir.forushgah.data.repository.ReturnItemDraft
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ReturnReason
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Phase 4.2: terminal order status safety. CANCELLED / DELETED / RETURNED
 * invoices can never be reopened into an active state through the normal
 * status transition — enforced in the repository (not just the UI), with no
 * financial side effects from the rejected attempt.
 */
@RunWith(RobolectricTestRunner::class)
class TerminalOrderStatusTest {

    private lateinit var db: AppDatabase
    private lateinit var orderRepository: OrderRepository

    @Before
    fun setup() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
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
            inventoryRepository = InventoryRepository(db, db.inventoryMovementDao()),
        )
    }

    @After
    fun teardown() {
        db.close()
    }

    // ---------- helpers ----------

    /** Creates a cash sales order for 2 units; returns (orderId, productId). */
    private suspend fun createCashOrder(): Pair<Long, Long> {
        val customerId = db.customerDao().insert(CustomerEntity(name = "مشتری", createdAt = 0, updatedAt = 0))
        val productId = db.productDao().insert(
            ProductEntity(
                name = "کالا", sku = "S-1",
                purchasePrice = Money(10_000), sellingPrice = Money(50_000),
                stockQuantity = 100, createdAt = 0, updatedAt = 0,
            ),
        )
        val order = orderRepository.createOrder(
            NewOrder(customerId = customerId, items = listOf(NewOrderItem(productId, 2, Money(50_000), Money(10_000)))),
        )
        return order.id to productId
    }

    private suspend fun statusOf(orderId: Long): OrderStatus =
        db.orderDao().getById(orderId)!!.status

    private suspend fun eventCountOf(orderId: Long): Int =
        db.financialTransactionDao().getByOrder(orderId).size

    // ---------- CANCELLED ----------

    @Test
    fun `cancelled order cannot be reopened into an active status`() = runBlocking {
        val (orderId, _) = createCashOrder()
        orderRepository.cancelOrder(orderId)
        assertThat(statusOf(orderId)).isEqualTo(OrderStatus.CANCELLED)
        val before = eventCountOf(orderId)

        val errorNew = runCatching { orderRepository.updateStatus(orderId, OrderStatus.NEW) }.exceptionOrNull()
        assertThat(errorNew).isInstanceOf(IllegalArgumentException::class.java)
        val errorConfirmed = runCatching { orderRepository.updateStatus(orderId, OrderStatus.CONFIRMED) }.exceptionOrNull()
        assertThat(errorConfirmed).isInstanceOf(IllegalArgumentException::class.java)

        assertThat(statusOf(orderId)).isEqualTo(OrderStatus.CANCELLED)
        // the rejected attempts changed nothing financially
        assertThat(eventCountOf(orderId)).isEqualTo(before)
    }

    @Test
    fun `cancelled order can still move to deleted (terminal to terminal)`() = runBlocking {
        val (orderId, _) = createCashOrder()
        orderRepository.cancelOrder(orderId)
        orderRepository.updateStatus(orderId, OrderStatus.DELETED)
        assertThat(statusOf(orderId)).isEqualTo(OrderStatus.DELETED)
    }

    // ---------- DELETED ----------

    @Test
    fun `deleted order cannot be reopened`() = runBlocking {
        val (orderId, _) = createCashOrder()
        orderRepository.cancelOrder(orderId)
        orderRepository.deleteOrder(orderId)
        assertThat(statusOf(orderId)).isEqualTo(OrderStatus.DELETED)
        val before = eventCountOf(orderId)

        val error = runCatching { orderRepository.updateStatus(orderId, OrderStatus.CONFIRMED) }.exceptionOrNull()
        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)

        assertThat(statusOf(orderId)).isEqualTo(OrderStatus.DELETED)
        assertThat(eventCountOf(orderId)).isEqualTo(before)
    }

    // ---------- RETURNED ----------

    @Test
    fun `returned order cannot be reopened`() = runBlocking {
        val (orderId, productId) = createCashOrder()
        orderRepository.createReturn(orderId, listOf(ReturnItemDraft(productId, 2)), ReturnReason.OTHER)
        assertThat(statusOf(orderId)).isEqualTo(OrderStatus.RETURNED)
        val before = eventCountOf(orderId)

        val error = runCatching { orderRepository.updateStatus(orderId, OrderStatus.NEW) }.exceptionOrNull()
        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)

        assertThat(statusOf(orderId)).isEqualTo(OrderStatus.RETURNED)
        assertThat(eventCountOf(orderId)).isEqualTo(before)
    }

    // ---------- regression: active-to-active still works ----------

    @Test
    fun `active orders still move between active statuses`() = runBlocking {
        val (orderId, _) = createCashOrder()
        orderRepository.updateStatus(orderId, OrderStatus.CONFIRMED)
        assertThat(statusOf(orderId)).isEqualTo(OrderStatus.CONFIRMED)
        orderRepository.updateStatus(orderId, OrderStatus.SHIPPED)
        assertThat(statusOf(orderId)).isEqualTo(OrderStatus.SHIPPED)
        orderRepository.updateStatus(orderId, OrderStatus.DELIVERED)
        assertThat(statusOf(orderId)).isEqualTo(OrderStatus.DELIVERED)
    }
}
