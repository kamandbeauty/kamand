package com.modir.forushgah.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.entity.CustomerEntity
import com.modir.forushgah.data.local.entity.OrderEntity
import com.modir.forushgah.data.local.entity.ShippingProviderEntity
import com.modir.forushgah.data.local.entity.SupplierEntity
import com.modir.forushgah.data.repository.ShipmentTrackingRepository
import com.modir.forushgah.data.repository.ShipmentTrackingUpdate
import com.modir.forushgah.domain.model.OrderKind
import com.modir.forushgah.domain.model.OrderStatus
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Phase 3.1 shipment tracking tests (spec §43.13–22): order-level tracking,
 * String codes with leading zeros, provider/date persistence, database-level
 * name search, multiple orders per customer, bulk + partial bulk save and
 * transaction rollback.
 */
@RunWith(RobolectricTestRunner::class)
class ShipmentTrackingTest {

    private lateinit var db: AppDatabase
    private lateinit var tracking: ShipmentTrackingRepository

    @Before
    fun setup() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        tracking = ShipmentTrackingRepository(db, db.orderDao())
    }

    @After
    fun teardown() {
        db.close()
    }

    private suspend fun seedCustomer(name: String, mobile: String? = "09120001111"): Long =
        db.customerDao().insert(CustomerEntity(name = name, mobile = mobile, createdAt = 0, updatedAt = 0))

    private suspend fun seedProvider(name: String): Long =
        db.shippingProviderDao().insert(ShippingProviderEntity(name = name))

    private suspend fun seedOrder(
        number: String,
        customerId: Long?,
        supplierId: Long? = null,
        kind: OrderKind = OrderKind.SALES,
        date: Long = 0,
        status: OrderStatus = OrderStatus.NEW,
    ): Long = db.orderDao().insertOrder(
        OrderEntity(
            orderNumber = number,
            customerId = customerId,
            supplierId = supplierId,
            kind = kind,
            orderDate = date,
            status = status,
        ),
    )

    // 13. search by customer name (database level) ---------------------------

    @Test
    fun `search finds orders by customer name and excludes others`() = runBlocking {
        val javad = seedCustomer("جاوید")
        val javadAhmadi = seedCustomer("جاوید احمدی")
        val sara = seedCustomer("سارا")
        seedOrder("1024", javad)
        seedOrder("1025", javadAhmadi)
        seedOrder("1026", sara)

        val results = tracking.observeForTracking("جاوید").first()
        assertThat(results).hasSize(2)
        assertThat(results.map { it.customerName }.toSet())
            .containsExactly("جاوید", "جاوید احمدی")
    }

    // 14. multiple orders for the same customer stay separate rows ----------

    @Test
    fun `same customer with many orders yields one row per order`() = runBlocking {
        val javad = seedCustomer("جاوید")
        seedOrder("1024", javad, date = 1)
        seedOrder("1058", javad, date = 2)
        seedOrder("1087", javad, date = 3)

        val results = tracking.observeForTracking("").first()
        assertThat(results).hasSize(3)
        assertThat(results.map { it.orderNumber }).containsExactly("1024", "1058", "1087")
        // Each row carries its own order id — tracking binds to the order.
        assertThat(results.map { it.orderId }.distinct()).hasSize(3)
    }

    // 15/16/17/18. persistence of code (String!), provider, date -------------

    @Test
    fun `tracking code is stored as an exact string preserving leading zeros`() = runBlocking {
        val customer = seedCustomer("جاوید")
        val orderId = seedOrder("1024", customer)

        tracking.saveTracking(
            ShipmentTrackingUpdate(orderId, null, "00123456789", null),
        )

        assertThat(db.orderDao().getById(orderId)?.trackingCode).isEqualTo("00123456789")
        val row = tracking.observeForTracking("").first().first { it.orderId == orderId }
        assertThat(row.trackingCode).isEqualTo("00123456789")
    }

    @Test
    fun `tracking codes with letters prefixes and hyphens survive intact`() = runBlocking {
        val customer = seedCustomer("محمد")
        val a = seedOrder("2001", customer)
        val b = seedOrder("2002", customer)

        tracking.saveTracking(ShipmentTrackingUpdate(a, null, "TP987654321", null))
        tracking.saveTracking(ShipmentTrackingUpdate(b, null, "AB-00123456", null))

        assertThat(db.orderDao().getById(a)?.trackingCode).isEqualTo("TP987654321")
        assertThat(db.orderDao().getById(b)?.trackingCode).isEqualTo("AB-00123456")
    }

    @Test
    fun `provider and shipping date are persisted on the order`() = runBlocking {
        val customer = seedCustomer("سارا")
        val orderId = seedOrder("1030", customer)
        val tipax = seedProvider("تیپاکس")
        val shippedAt = 1_767_225_600_000L

        tracking.saveTracking(ShipmentTrackingUpdate(orderId, tipax, "TP123", shippedAt))

        val order = db.orderDao().getById(orderId)!!
        assertThat(order.shippingProviderId).isEqualTo(tipax)
        assertThat(order.shippedAt).isEqualTo(shippedAt)
        val row = tracking.observeForTracking("").first().first { it.orderId == orderId }
        assertThat(row.providerName).isEqualTo("تیپاکس")
    }

    // 19. tracking belongs to the specific order -----------------------------

    @Test
    fun `two orders of the same customer keep independent tracking`() = runBlocking {
        val customer = seedCustomer("جاوید")
        val post = seedProvider("پست")
        val tipax = seedProvider("تیپاکس")
        val a = seedOrder("3001", customer)
        val b = seedOrder("3002", customer)

        tracking.saveTracking(ShipmentTrackingUpdate(a, post, "A111", 1000L))
        tracking.saveTracking(ShipmentTrackingUpdate(b, tipax, "B222", 2000L))

        val rows = tracking.observeForTracking("").first().associateBy { it.orderId }
        assertThat(rows[a]!!.trackingCode).isEqualTo("A111")
        assertThat(rows[a]!!.providerName).isEqualTo("پست")
        assertThat(rows[b]!!.trackingCode).isEqualTo("B222")
        assertThat(rows[b]!!.providerName).isEqualTo("تیپاکس")
    }

    // 20/21. bulk save + partial bulk save ------------------------------------

    @Test
    fun `bulk save commits many orders in one call`() = runBlocking {
        val c1 = seedCustomer("جاوید")
        val c2 = seedCustomer("محمد")
        val c3 = seedCustomer("سارا")
        val a = seedOrder("4001", c1)
        val b = seedOrder("4002", c2)
        val c = seedOrder("4003", c3)

        val saved = tracking.bulkSaveTracking(
            listOf(
                ShipmentTrackingUpdate(a, null, "K1", 1L),
                ShipmentTrackingUpdate(b, null, "K2", 2L),
                ShipmentTrackingUpdate(c, null, "K3", 3L),
            ),
        )

        assertThat(saved).isEqualTo(3)
        assertThat(db.orderDao().getById(a)?.trackingCode).isEqualTo("K1")
        assertThat(db.orderDao().getById(b)?.trackingCode).isEqualTo("K2")
        assertThat(db.orderDao().getById(c)?.trackingCode).isEqualTo("K3")
    }

    @Test
    fun `partial bulk save leaves untouched orders unchanged`() = runBlocking {
        val customer = seedCustomer("جاوید")
        val a = seedOrder("5001", customer)
        val b = seedOrder("5002", customer)
        val c = seedOrder("5003", customer)
        val d = seedOrder("5004", customer)
        val e = seedOrder("5005", customer)

        // Only 2 of 5 orders have tracking info entered.
        tracking.bulkSaveTracking(
            listOf(
                ShipmentTrackingUpdate(a, null, "X1", null),
                ShipmentTrackingUpdate(c, null, "X3", null),
            ),
        )

        assertThat(db.orderDao().getById(a)?.trackingCode).isEqualTo("X1")
        assertThat(db.orderDao().getById(b)?.trackingCode).isNull()
        assertThat(db.orderDao().getById(c)?.trackingCode).isEqualTo("X3")
        assertThat(db.orderDao().getById(d)?.trackingCode).isNull()
        assertThat(db.orderDao().getById(e)?.trackingCode).isNull()
    }

    // 22. transaction rollback ------------------------------------------------

    @Test
    fun `bulk save rolls back the whole batch when one row fails`() = runBlocking {
        val customer = seedCustomer("جاوید")
        val a = seedOrder("6001", customer)

        // First update is valid; the second references a nonexistent order →
        // the transaction must fail and NOTHING may be persisted.
        val exception = runCatching {
            tracking.bulkSaveTracking(
                listOf(
                    ShipmentTrackingUpdate(a, null, "VALID", 1L),
                    ShipmentTrackingUpdate(99_999, null, "INVALID", 1L),
                ),
            )
        }.exceptionOrNull()

        assertThat(exception).isNotNull()
        assertThat(db.orderDao().getById(a)?.trackingCode).isNull()
        assertThat(db.orderDao().getById(a)?.shippedAt).isNull()
    }

    // 23. tracking update (re-save) -------------------------------------------

    @Test
    fun `saving tracking twice keeps the latest value`() = runBlocking {
        val customer = seedCustomer("علی")
        val orderId = seedOrder("7001", customer)

        tracking.saveTracking(ShipmentTrackingUpdate(orderId, null, "OLD", null))
        tracking.saveTracking(ShipmentTrackingUpdate(orderId, null, "NEW", 42L))

        val order = db.orderDao().getById(orderId)!!
        assertThat(order.trackingCode).isEqualTo("NEW")
        assertThat(order.shippedAt).isEqualTo(42L)
    }

    // 28. missing phone is visible to the UI (sms guard) -----------------------

    @Test
    fun `rows expose the customer mobile so the sms guard can react`() = runBlocking {
        val withPhone = seedCustomer("جاوید", mobile = "09120001111")
        val withoutPhone = seedCustomer("بی‌موبایل", mobile = null)
        val a = seedOrder("8001", withPhone)
        val b = seedOrder("8002", withoutPhone)

        val rows = tracking.observeForTracking("").first().associateBy { it.orderId }
        assertThat(rows[a]!!.customerMobile).isEqualTo("09120001111")
        assertThat(rows[b]!!.customerMobile).isNull()
    }

    // 27. purchase invoices track their supplier name --------------------------

    @Test
    fun `purchase orders show the supplier name as the party`() = runBlocking {
        val supplier = db.supplierDao().insert(
            SupplierEntity(name = "شرکت پخش آریا", createdAt = 0, updatedAt = 0),
        )
        val order = seedOrder("9001", customerId = null, supplierId = supplier, kind = OrderKind.PURCHASE)

        val row = tracking.observeForTracking("").first().first { it.orderId == order }
        assertThat(row.customerName).isEqualTo("شرکت پخش آریا")
        assertThat(row.isPurchase).isTrue()
    }
}
