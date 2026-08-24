package com.modir.forushgah.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.entity.CustomerEntity
import com.modir.forushgah.data.local.entity.PaymentEntity
import com.modir.forushgah.data.local.entity.ProductEntity
import com.modir.forushgah.data.repository.InventoryRepository
import com.modir.forushgah.data.repository.NewOrder
import com.modir.forushgah.data.repository.NewOrderItem
import com.modir.forushgah.data.repository.OrderRepository
import com.modir.forushgah.data.repository.ReturnItemDraft
import com.modir.forushgah.domain.model.InsufficientStockException
import com.modir.forushgah.domain.model.InventoryMovementType
import com.modir.forushgah.domain.model.InventoryReferenceType
import com.modir.forushgah.domain.model.OrderStatus
import com.modir.forushgah.domain.model.ReturnReason
import com.modir.forushgah.domain.model.ShippingPaymentType
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

/**
 * Spec §19/§20/§21/§24/§26/§30: transactional order lifecycle against a real
 * in-memory Room database. Verifies stock deduction, idempotency (an order
 * can never deduct/restore stock twice), cancellation, full/partial returns
 * and refund history preservation.
 */
@RunWith(RobolectricTestRunner::class)
class OrderRepositoryTest {

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

    private suspend fun seedCustomer(name: String = "مشتری نمونه"): Long =
        db.customerDao().insert(CustomerEntity(name = name, createdAt = 0, updatedAt = 0))

    private suspend fun seedProduct(name: String = "کالا", stock: Int = 20): Long =
        db.productDao().insert(
            ProductEntity(
                name = name, sku = "S-$name", purchasePrice = Money(10_000), sellingPrice = Money(50_000),
                stockQuantity = stock, createdAt = 0, updatedAt = 0,
            ),
        )

    private suspend fun stockOf(productId: Long): Int =
        db.productDao().getById(productId)?.stockQuantity ?: -1

    private suspend fun newOrder(productId: Long, customerId: Long, quantity: Int = 1): Long {
        val order = orderRepository.createOrder(
            NewOrder(
                customerId = customerId,
                items = listOf(NewOrderItem(productId, quantity, Money(50_000), Money(10_000))),
                shippingPaymentType = ShippingPaymentType.SELLER_PAID,
            ),
        )
        return order.id
    }

    // ---------- spec §19: create order + SALE movement, atomically ----------

    @Test
    fun `creating an order deducts stock and writes a SALE movement referencing the order`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 20)
        val orderId = newOrder(product, customer, quantity = 3)

        // Spec §19 example: stock 20, order 3 -> 17.
        assertThat(stockOf(product)).isEqualTo(17)
        assertThat(
            db.inventoryMovementDao().countByReference(
                InventoryReferenceType.ORDER.name, orderId, InventoryMovementType.SALE.name,
            ),
        ).isEqualTo(1)
        val movements = db.inventoryMovementDao().observeForProduct(product).first()
        val sale = movements.single { it.quantityDelta == -3 }
        assertThat(sale.referenceId).isEqualTo(orderId)
        assertThat(sale.stockBefore).isEqualTo(20)
        assertThat(sale.stockAfter).isEqualTo(17)
    }

    @Test
    fun `selling more than available stock is rejected and rolls back the whole order`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 2)

        val exception = runCatching {
            orderRepository.createOrder(
                NewOrder(customerId = customer, items = listOf(NewOrderItem(product, 5, Money(50_000), Money(10_000)))),
            )
        }.exceptionOrNull()

        assertThat(exception).isInstanceOf(InsufficientStockException::class.java)
        assertThat(stockOf(product)).isEqualTo(2) // untouched
        assertThat(db.orderDao().observeAll().first()).isEmpty() // no partial order left behind
    }

    // ---------- spec §20: cancel restores stock, idempotently ----------

    @Test
    fun `cancelling an order restores stock and double cancel does not restore twice`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 20)
        val orderId = newOrder(product, customer, quantity = 3)
        assertThat(stockOf(product)).isEqualTo(17)

        orderRepository.cancelOrder(orderId)
        assertThat(stockOf(product)).isEqualTo(20) // spec §20 example: 17 -> 20

        // Idempotency: cancelling again must not add stock back a second time.
        orderRepository.cancelOrder(orderId)
        assertThat(stockOf(product)).isEqualTo(20)
        assertThat(
            db.inventoryMovementDao().countByReference(
                InventoryReferenceType.ORDER.name, orderId, InventoryMovementType.RETURN.name,
            ),
        ).isEqualTo(1)
    }

    // ---------- spec §21: full and partial returns ----------

    @Test
    fun `full return restocks everything and marks the order RETURNED`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 20)
        val orderId = newOrder(product, customer, quantity = 5)
        assertThat(stockOf(product)).isEqualTo(15)

        orderRepository.createReturn(
            orderId = orderId,
            items = listOf(ReturnItemDraft(product, 5)),
            reason = ReturnReason.DEFECTIVE,
            restockedToInventory = true,
        )

        assertThat(stockOf(product)).isEqualTo(20)
        assertThat(db.orderDao().getById(orderId)?.status).isEqualTo(OrderStatus.RETURNED)
    }

    @Test
    fun `partial return restocks only the returned units and caps further returns`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 20)
        val orderId = newOrder(product, customer, quantity = 5)
        assertThat(stockOf(product)).isEqualTo(15)

        // Return 2 of 5 (spec §21 example).
        orderRepository.createReturn(orderId, listOf(ReturnItemDraft(product, 2)), ReturnReason.WRONG_ITEM)
        assertThat(stockOf(product)).isEqualTo(17)
        assertThat(db.orderDao().getById(orderId)?.status).isNotEqualTo(OrderStatus.RETURNED)

        // Return 2 more -> 19.
        orderRepository.createReturn(orderId, listOf(ReturnItemDraft(product, 2)), ReturnReason.WRONG_ITEM)
        assertThat(stockOf(product)).isEqualTo(19)

        // Only 1 unit left to return — asking for 3 must be rejected, stock unchanged.
        val exception = runCatching {
            orderRepository.createReturn(orderId, listOf(ReturnItemDraft(product, 3)), ReturnReason.WRONG_ITEM)
        }.exceptionOrNull()
        assertThat(exception).isInstanceOf(IllegalArgumentException::class.java)
        assertThat(stockOf(product)).isEqualTo(19)
    }

    // ---------- spec §18/§24: payments and refunds ----------

    @Test
    fun `partial payment then refund keeps the original payment history`() = runBlocking {
        val customer = seedCustomer()
        val product = seedProduct(stock = 20)
        val orderId = newOrder(product, customer, quantity = 100) // total = 5,000,000

        // Order total: 100 x 50,000 = 5,000,000 (seller-paid shipping => no extra).
        orderRepository.recordPayment(orderId, Money(3_000_000), "نقدی")
        val remainingAfterPartial =
            (5_000_000 - db.paymentDao().sumPaidForOrder(orderId)).let { Money(it) }
        assertThat(remainingAfterPartial).isEqualTo(Money(2_000_000)) // spec §18 example

        // Overpaying is rejected.
        val overpay = runCatching { orderRepository.recordPayment(orderId, Money(2_500_000), "نقدی") }
            .exceptionOrNull()
        assertThat(overpay).isInstanceOf(IllegalArgumentException::class.java)

        // Refund the paid amount; the payment rows must survive.
        orderRepository.createRefund(orderId, Money(3_000_000), "کارت بانکی", "مرجوعی")
        assertThat(db.paymentDao().getForOrder(orderId)).hasSize(1)
        assertThat(db.refundDao().observeForOrder(orderId).first()).hasSize(1)
        assertThat(db.refundDao().sumRefundedForOrder(orderId)).isEqualTo(3_000_000)

        // Refunding more than paid is rejected.
        val overRefund = runCatching { orderRepository.createRefund(orderId, Money(1), "نقدی", "تست") }
            .exceptionOrNull()
        assertThat(overRefund).isInstanceOf(IllegalArgumentException::class.java)
    }
}
