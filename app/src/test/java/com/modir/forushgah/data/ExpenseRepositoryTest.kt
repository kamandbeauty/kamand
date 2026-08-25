package com.modir.forushgah.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.entity.CustomerEntity
import com.modir.forushgah.data.local.entity.ProductEntity
import com.modir.forushgah.data.repository.CustomerRepository
import com.modir.forushgah.data.repository.ExpenseRepository
import com.modir.forushgah.data.repository.InventoryRepository
import com.modir.forushgah.data.repository.NewExpense
import com.modir.forushgah.data.repository.NewOrder
import com.modir.forushgah.data.repository.NewOrderItem
import com.modir.forushgah.data.repository.OrderRepository
import com.modir.forushgah.domain.model.Customer
import com.modir.forushgah.domain.model.ExpenseGroup
import com.modir.forushgah.domain.model.TransactionType
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Phase 4.2: the standalone expense workflow against a real in-memory Room
 * database — creation + negative EXPENSE event, exactly-once built-in
 * category seeding, edit reversal with exact net effect, soft delete with
 * exactly-once reversal, idempotency, validation, the packaging-independence
 * business rule and customer-balance safety.
 */
@RunWith(RobolectricTestRunner::class)
class ExpenseRepositoryTest {

    private lateinit var db: AppDatabase
    private lateinit var expenseRepository: ExpenseRepository
    private lateinit var orderRepository: OrderRepository
    private lateinit var customerRepository: CustomerRepository

    @Before
    fun setup() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        expenseRepository = ExpenseRepository(
            database = db,
            expenseDao = db.expenseDao(),
            expenseCategoryDao = db.expenseCategoryDao(),
            financialTransactionDao = db.financialTransactionDao(),
        )
        customerRepository = CustomerRepository(db.customerDao())
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
        runBlocking { expenseRepository.seedBuiltInCategories() }
    }

    @After
    fun teardown() {
        db.close()
    }

    // ---------- helpers ----------

    private suspend fun packagingCategoryId(): Long =
        db.expenseCategoryDao().observeAll().first().first { it.group == ExpenseGroup.PACKAGING }.id

    private suspend fun createPackagingExpense(
        amount: Long = 5_000_000,
        date: Long = 1_700_000_000_000L,
    ): Long = expenseRepository.createExpense(
        NewExpense(
            categoryId = packagingCategoryId(),
            amount = Money(amount),
            date = date,
            description = "خرید کیسه و جعبه",
        ),
    ).id

    private suspend fun eventsFor(expenseId: Long) =
        db.financialTransactionDao().getByReference(ExpenseRepository.EXPENSE_REFERENCE_TYPE, expenseId)

    private suspend fun netOf(expenseId: Long): Long = eventsFor(expenseId).sumOf { it.amount.amountInToman }

    private suspend fun allEvents() =
        db.financialTransactionDao().observeBetween(0L, Long.MAX_VALUE).first()

    private suspend fun seedCustomer(name: String = "مشتری"): Long =
        db.customerDao().insert(CustomerEntity(name = name, createdAt = 0, updatedAt = 0))

    private suspend fun seedProduct(name: String = "کالا", stock: Int = 100): Long =
        db.productDao().insert(
            ProductEntity(
                name = name, sku = name,
                purchasePrice = Money(50_000), sellingPrice = Money(100_000),
                stockQuantity = stock, createdAt = 0, updatedAt = 0,
            ),
        )

    // ---------- 1. creation ----------

    @Test
    fun `creating a five million packaging expense writes the row and a negative EXPENSE event`() = runBlocking {
        val id = createPackagingExpense()

        val row = db.expenseDao().getById(id)!!
        assertThat(row.amount).isEqualTo(Money(5_000_000))
        assertThat(row.categoryId).isEqualTo(packagingCategoryId())
        assertThat(row.deletedAt).isNull()

        val events = eventsFor(id)
        assertThat(events).hasSize(1)
        val event = events.single()
        assertThat(event.type).isEqualTo(TransactionType.EXPENSE)
        assertThat(event.amount).isEqualTo(Money(-5_000_000))
        assertThat(event.referenceType).isEqualTo("EXPENSE")
        assertThat(event.referenceId).isEqualTo(id)
        assertThat(event.date).isEqualTo(1_700_000_000_000L)
        assertThat(event.reversalOfId).isNull()
        assertThat(event.orderId).isNull()

        // visible in the active list with its category name and in the total
        val list = expenseRepository.observeExpenses().first()
        assertThat(list).hasSize(1)
        assertThat(list.single().categoryName).isEqualTo("بسته‌بندی")
        assertThat(expenseRepository.observeTotal().first()).isEqualTo(Money(5_000_000))
    }

    // ---------- 2. category seeding ----------

    @Test
    fun `built-in categories are seeded exactly once with the final seven groups`() = runBlocking {
        // setup already seeded once — a second start must not duplicate
        expenseRepository.seedBuiltInCategories()

        val categories = db.expenseCategoryDao().observeAll().first()
        assertThat(categories).hasSize(7)
        // seven distinct names (Truth 1.4.2 has no doesNotContainDuplicates)
        assertThat(categories.map { it.name }.toSet()).hasSize(7)
        assertThat(categories.map { it.group }.toSet()).hasSize(ExpenseGroup.entries.size)
        assertThat(categories.all { it.isBuiltIn }).isTrue()
        assertThat(categories.map { it.name }).containsExactly(
            "بسته‌بندی", "ارسال", "خرید", "اجاره", "حقوق", "قبوض و خدمات", "سایر",
        )
    }

    // ---------- 3. edit ----------

    @Test
    fun `editing from five to seven reverses the original and writes the new event`() = runBlocking {
        val id = createPackagingExpense()
        val original = eventsFor(id).single()

        expenseRepository.updateExpense(
            id,
            NewExpense(
                categoryId = packagingCategoryId(),
                amount = Money(7_000_000),
                date = 1_700_010_000_000L,
                description = "خرید کیسه و جعبه — مرحله دوم",
            ),
        )

        val events = eventsFor(id)
        assertThat(events.filter { it.reversalOfId == null }).hasSize(2) // original + new
        assertThat(events.filter { it.reversalOfId != null }).hasSize(1) // the reversal

        val reversal = events.single { it.reversalOfId == original.id }
        assertThat(reversal.type).isEqualTo(TransactionType.EXPENSE)
        assertThat(reversal.amount).isEqualTo(Money(5_000_000))

        // the original event is reversed exactly once
        assertThat(db.financialTransactionDao().countReversalsOf(original.id)).isEqualTo(1)

        // the row carries the new value; the net financial effect is -7M
        assertThat(db.expenseDao().getById(id)!!.amount).isEqualTo(Money(7_000_000))
        assertThat(netOf(id)).isEqualTo(-7_000_000L)
        assertThat(expenseRepository.observeTotal().first()).isEqualTo(Money(7_000_000))
    }

    @Test
    fun `editing a deleted expense is rejected`() = runBlocking {
        val id = createPackagingExpense()
        expenseRepository.deleteExpense(id)

        val error = runCatching {
            expenseRepository.updateExpense(
                id,
                NewExpense(packagingCategoryId(), Money(7_000_000), 1_700_010_000_000L),
            )
        }.exceptionOrNull()
        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)
        assertThat(netOf(id)).isEqualTo(0L)
    }

    // ---------- 4. delete ----------

    @Test
    fun `delete soft-deletes, reverses exactly once, and repeated deletes are no-ops`() = runBlocking {
        val id = createPackagingExpense()
        val original = eventsFor(id).single()

        expenseRepository.deleteExpense(id)
        expenseRepository.deleteExpense(id) // idempotent — no second reversal

        val row = db.expenseDao().getById(id)!!
        assertThat(row.deletedAt).isNotNull()
        // gone from the active list and total, still preserved in the table
        assertThat(expenseRepository.observeExpenses().first()).isEmpty()
        assertThat(expenseRepository.observeTotal().first()).isEqualTo(Money(0))
        assertThat(db.expenseDao().observeAll().first()).hasSize(1)

        val events = eventsFor(id)
        assertThat(events).hasSize(2)
        val reversal = events.single { it.reversalOfId != null }
        assertThat(reversal.reversalOfId).isEqualTo(original.id)
        assertThat(reversal.amount).isEqualTo(Money(5_000_000))
        assertThat(db.financialTransactionDao().countReversalsOf(original.id)).isEqualTo(1)
        assertThat(netOf(id)).isEqualTo(0L)
    }

    // ---------- 5. idempotency ----------

    @Test
    fun `repeated edits never reverse an event twice and keep the net exact`() = runBlocking {
        val id = createPackagingExpense(5_000_000)
        expenseRepository.updateExpense(id, NewExpense(packagingCategoryId(), Money(7_000_000), 1_700_010_000_000L))
        expenseRepository.updateExpense(id, NewExpense(packagingCategoryId(), Money(6_000_000), 1_700_020_000_000L))

        val events = eventsFor(id)
        assertThat(events.filter { it.reversalOfId == null }).hasSize(3) // 5M, 7M, 6M
        assertThat(events.filter { it.reversalOfId != null }).hasSize(2) // 5M and 7M reversed
        for (event in events) {
            if (event.reversalOfId == null) {
                assertThat(db.financialTransactionDao().countReversalsOf(event.id))
                    .isAtMost(1)
            }
        }
        assertThat(db.expenseDao().getById(id)!!.amount).isEqualTo(Money(6_000_000))
        assertThat(netOf(id)).isEqualTo(-6_000_000L)
    }

    // ---------- 6. validation ----------

    @Test
    fun `zero amount is rejected without any side effect`() = runBlocking {
        val error = runCatching {
            expenseRepository.createExpense(NewExpense(packagingCategoryId(), Money(0), 1_700_000_000_000L))
        }.exceptionOrNull()
        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)
        assertThat(db.expenseDao().observeAll().first()).isEmpty()
        assertThat(allEvents()).isEmpty()
    }

    @Test
    fun `negative amount is rejected without any side effect`() = runBlocking {
        val error = runCatching {
            expenseRepository.createExpense(NewExpense(packagingCategoryId(), Money(-100_000), 1_700_000_000_000L))
        }.exceptionOrNull()
        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)
        assertThat(db.expenseDao().observeAll().first()).isEmpty()
        assertThat(allEvents()).isEmpty()
    }

    @Test
    fun `invalid date is rejected`() = runBlocking {
        val error = runCatching {
            expenseRepository.createExpense(NewExpense(packagingCategoryId(), Money(1_000), 0L))
        }.exceptionOrNull()
        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)
    }

    @Test
    fun `unknown category is rejected`() = runBlocking {
        val error = runCatching {
            expenseRepository.createExpense(NewExpense(categoryId = 999, amount = Money(1_000), date = 1_700_000_000_000L))
        }.exceptionOrNull()
        assertThat(error).isInstanceOf(IllegalStateException::class.java)
        assertThat(db.expenseDao().observeAll().first()).isEmpty()
    }

    // ---------- 7. packaging business rule ----------

    @Test
    fun `bulk packaging expense is independent of invoice packagingCost`() = runBlocking {
        val customerId = seedCustomer()
        val product = seedProduct()

        // A) the bulk purchase — a standalone expense
        val expenseId = createPackagingExpense()

        // B) an invoice without a packaging charge — nothing is auto-allocated
        val orderA = orderRepository.createOrder(
            NewOrder(customerId = customerId, items = listOf(NewOrderItem(product, 1, Money(100_000), Money(50_000)))),
        )
        val orderAEvents = db.financialTransactionDao().getByOrder(orderA.id)
        assertThat(orderAEvents.filter { it.type == TransactionType.PACKAGING_EXPENSE }).isEmpty()
        // the bulk expense was not distributed across the invoice
        assertThat(orderAEvents.filter { it.referenceType == "EXPENSE" }).isEmpty()
        // and the expense side was not linked to the invoice
        assertThat(eventsFor(expenseId).single().orderId).isNull()

        // C) an invoice that explicitly charges packaging — its own event,
        //    and still nothing on the expense side
        val orderB = orderRepository.createOrder(
            NewOrder(
                customerId = customerId,
                packagingCost = Money(25_000),
                items = listOf(NewOrderItem(product, 1, Money(100_000), Money(50_000))),
            ),
        )
        val orderBEvents = db.financialTransactionDao().getByOrder(orderB.id)
        assertThat(orderBEvents.filter { it.type == TransactionType.PACKAGING_EXPENSE }).hasSize(1)
        assertThat(orderBEvents.single { it.type == TransactionType.PACKAGING_EXPENSE }.amount)
            .isEqualTo(Money(-25_000))
        assertThat(eventsFor(expenseId)).hasSize(1)
        assertThat(netOf(expenseId)).isEqualTo(-5_000_000L)
    }

    // ---------- 8. customer balance safety ----------

    @Test
    fun `expense create and delete never touch the customer credit balance`() = runBlocking {
        val customerId = seedCustomer()
        val product = seedProduct()
        orderRepository.createOrder(
            NewOrder(customerId = customerId, cashPayment = false, items = listOf(NewOrderItem(product, 2, Money(100_000), Money(50_000)))),
        )
        val balanceAfterCredit = db.customerDao().getById(customerId)!!.balance
        assertThat(balanceAfterCredit.amountInToman).isEqualTo(200_000L)

        val expenseId = createPackagingExpense()
        assertThat(db.customerDao().getById(customerId)!!.balance).isEqualTo(balanceAfterCredit)

        expenseRepository.deleteExpense(expenseId)
        assertThat(db.customerDao().getById(customerId)!!.balance).isEqualTo(balanceAfterCredit)
    }

    @Test
    fun `customer profile update preserves the derived balance`() = runBlocking {
        val customerId = seedCustomer()
        val product = seedProduct()
        orderRepository.createOrder(
            NewOrder(customerId = customerId, cashPayment = false, items = listOf(NewOrderItem(product, 1, Money(100_000), Money(50_000)))),
        )
        val derived = db.customerDao().getById(customerId)!!.balance
        assertThat(derived.amountInToman).isEqualTo(100_000L)

        // The edit form round-trips a Customer without a balance (defaults to
        // zero) — the repository must not let that overwrite the derived value.
        customerRepository.update(
            Customer(id = customerId, name = "مشتری ویرایش‌شده", createdAt = 0, updatedAt = 0),
        )
        val updated = db.customerDao().getById(customerId)!!
        assertThat(updated.name).isEqualTo("مشتری ویرایش‌شده")
        assertThat(updated.balance).isEqualTo(derived)
    }
}
