package ir.javid.hesabyar.data.repository

import androidx.room.withTransaction
import ir.javid.hesabyar.core.common.PersianDate
import ir.javid.hesabyar.core.common.ValidationResult
import ir.javid.hesabyar.core.common.validateNonBlank
import ir.javid.hesabyar.core.model.*
import ir.javid.hesabyar.data.local.HesabyarDatabase
import ir.javid.hesabyar.data.local.dao.*
import ir.javid.hesabyar.data.local.entity.*
import ir.javid.hesabyar.domain.repository.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlin.math.roundToLong
import javax.inject.Inject

class DashboardRepositoryImpl @Inject constructor(
    dashboardDao: DashboardDao,
    cashDao: CashDao
) : DashboardRepository {
    override val summary: Flow<DashboardSummary> = combine(
        dashboardDao.salesToday(PersianDate.today()),
        dashboardDao.purchasesToday(PersianDate.today()),
        dashboardDao.profitToday(PersianDate.today()),
        cashDao.observeCashBalance(),
        cashDao.observeBankBalance(),
        dashboardDao.invoiceCountToday(PersianDate.today()),
        dashboardDao.debtorsTotal(),
        dashboardDao.creditorsTotal(),
        dashboardDao.lowStockCount()
    ) { values ->
        DashboardSummary(
            salesToday = values[0] as Long, purchasesToday = values[1] as Long,
            profitToday = values[2] as Long, cashBalance = values[3] as Long,
            bankBalance = values[4] as Long, invoicesToday = values[5] as Int,
            debtors = values[6] as Long, creditors = values[7] as Long,
            lowStockCount = values[8] as Int
        )
    }
}

class SettingsRepositoryImpl @Inject constructor(private val dao: SettingsDao) : SettingsRepository {
    override val settings: Flow<AppSettingsEntity> = dao.observe().map { it ?: AppSettingsEntity() }
    override val license: Flow<LicenseStatus> = dao.observeLicense().map { license ->
        val active = license?.tier == "PRO" && (license.expiresAt == null || license.expiresAt > System.currentTimeMillis())
        if (active) LicenseStatus("PRO", true, "نسخه حرفه‌ای فعال است") else LicenseStatus(reason = "نسخه رایگان")
    }

    override suspend fun save(settings: AppSettingsEntity) {
        require(validateNonBlank(settings.businessName.ifBlank { "کسب‌وکار" }, "نام کسب‌وکار") is ValidationResult.Valid)
        dao.save(settings.copy(id = 1, updatedAt = System.currentTimeMillis()))
    }

    /** Local license seam; server verification can replace this implementation later. */
    override suspend fun activateProfessional(token: String): Result<Unit> = runCatching {
        require(token.trim().length >= 8) { "کد فعال‌سازی معتبر نیست" }
        dao.saveLicense(LicenseEntity(tier = "PRO", activatedAt = System.currentTimeMillis(), token = token.trim()))
    }
}

class ProductRepositoryImpl @Inject constructor(
    private val db: HesabyarDatabase,
    private val dao: ProductDao
) : ProductRepository {
    override val products = dao.observeAll()
    override val categories = dao.observeCategories()
    override val lowStock = dao.observeLowStock()
    override fun search(query: String) = dao.search(query.trim())

    override suspend fun save(product: ProductEntity): Result<Long> = runCatching {
        require(product.name.trim().isNotEmpty()) { "نام کالا را وارد کنید" }
        require(product.purchasePrice >= 0 && product.salePrice >= 0) { "قیمت کالا نامعتبر است" }
        require(product.minimumStock >= 0) { "حداقل موجودی نمی‌تواند منفی باشد" }
        db.withTransaction {
            val now = System.currentTimeMillis()
            if (product.id == 0L) {
                val id = dao.insert(product.copy(name = product.name.trim(), sku = product.sku?.trim()?.ifBlank { null }, createdAt = now, updatedAt = now))
                if (product.trackInventory && product.stock != 0.0) {
                    dao.insertInventoryTransaction(InventoryTransactionEntity(productId = id, type = "ADJUSTMENT", quantity = product.stock, unitCost = product.purchasePrice, dateEpochDay = PersianDate.today(), note = "موجودی اولیه"))
                }
                id
            } else {
                val old = requireNotNull(dao.getById(product.id)) { "کالا پیدا نشد" }
                val stockDelta = product.stock - old.stock
                dao.update(product.copy(name = product.name.trim(), createdAt = old.createdAt, updatedAt = now))
                if (product.trackInventory && stockDelta != 0.0) dao.insertInventoryTransaction(InventoryTransactionEntity(productId = product.id, type = "ADJUSTMENT", quantity = stockDelta, unitCost = product.purchasePrice, dateEpochDay = PersianDate.today(), note = "اصلاح موجودی از فرم کالا"))
                product.id
            }
        }
    }

    override suspend fun archive(id: Long): Result<Unit> = runCatching { dao.archive(id) }
    override suspend fun saveCategory(category: ProductCategoryEntity): Result<Long> = runCatching {
        require(category.name.trim().isNotEmpty()) { "نام دسته‌بندی را وارد کنید" }
        if (category.id == 0L) dao.insertCategory(category.copy(name = category.name.trim()))
        else { dao.updateCategory(category.copy(name = category.name.trim(), updatedAt = System.currentTimeMillis())); category.id }
    }
    override suspend fun deleteCategory(category: ProductCategoryEntity): Result<Unit> = runCatching { dao.deleteCategory(category) }
    override fun inventory(productId: Long) = dao.observeInventory(productId)
    override suspend fun adjustStock(productId: Long, quantity: Double, note: String, dateEpochDay: Long): Result<Unit> = runCatching {
        require(quantity != 0.0) { "مقدار تغییر موجودی را وارد کنید" }
        db.withTransaction {
            requireNotNull(dao.getById(productId)) { "کالا پیدا نشد" }
            dao.updateStock(productId, quantity)
            dao.insertInventoryTransaction(InventoryTransactionEntity(productId = productId, type = "ADJUSTMENT", quantity = quantity, dateEpochDay = dateEpochDay, note = note.ifBlank { "اصلاح موجودی" }))
        }
    }
}

class PartyRepositoryImpl @Inject constructor(
    private val db: HesabyarDatabase,
    private val dao: PartyDao
) : PartyRepository {
    override val parties = dao.observeAll()
    override val debtors = dao.observeDebtors()
    override val creditors = dao.observeCreditors()
    override fun byType(type: String) = dao.observeByType(type)
    override fun search(query: String) = dao.search(query.trim())

    override suspend fun save(party: PartyEntity): Result<Long> = runCatching {
        require(party.name.trim().isNotEmpty()) { "نام شخص را وارد کنید" }
        require(party.type in setOf("CUSTOMER", "SUPPLIER", "OTHER")) { "نوع شخص نامعتبر است" }
        db.withTransaction {
            if (party.id == 0L) {
                val id = dao.insert(party.copy(name = party.name.trim()))
                if (party.balance != 0L) dao.insertTransaction(PartyTransactionEntity(partyId = id, type = "OPENING_BALANCE", amount = party.balance, dateEpochDay = PersianDate.today(), note = "مانده اول دوره"))
                id
            } else {
                val old = requireNotNull(dao.getById(party.id)) { "شخص پیدا نشد" }
                val delta = party.balance - old.balance
                dao.update(party.copy(name = party.name.trim(), createdAt = old.createdAt, updatedAt = System.currentTimeMillis()))
                if (delta != 0L) dao.insertTransaction(PartyTransactionEntity(partyId = party.id, type = "ADJUSTMENT", amount = delta, dateEpochDay = PersianDate.today(), note = "اصلاح مانده"))
                party.id
            }
        }
    }

    override suspend fun archive(id: Long): Result<Unit> = runCatching { dao.archive(id) }
    override fun transactions(partyId: Long) = dao.observeTransactions(partyId)
}

class InvoiceRepositoryImpl @Inject constructor(
    private val db: HesabyarDatabase,
    private val salesDao: SalesDao,
    private val purchaseDao: PurchaseDao,
    private val productDao: ProductDao,
    private val partyDao: PartyDao,
    private val cashDao: CashDao,
    private val settingsDao: SettingsDao,
    accountingDao: AccountingDao
) : InvoiceRepository {
    private val journal = JournalPoster(accountingDao)
    override val sales = salesDao.observeInvoices()
    override val purchases = purchaseDao.observeInvoices()

    override suspend fun createSale(input: InvoiceInput): Result<Long> = createInvoice(InvoiceKind.SALE, input)
    override suspend fun createPurchase(input: InvoiceInput): Result<Long> = createInvoice(InvoiceKind.PURCHASE, input)

    private suspend fun createInvoice(kind: InvoiceKind, input: InvoiceInput): Result<Long> = runCatching {
        validateInvoice(input)
        db.withTransaction {
            val calculated = calculate(input)
            require(input.paidAmount <= calculated.total) { "مبلغ پرداختی نباید از مبلغ فاکتور بیشتر باشد" }
            val due = calculated.total - input.paidAmount
            require(due == 0L || input.partyId != null) { "برای مبلغ باقی‌مانده، طرف حساب را انتخاب کنید" }
            if (input.cashAccountId != null) requireNotNull(cashDao.getAccount(input.cashAccountId)) { "حساب نقدی پیدا نشد" }
            if (input.partyId != null) requireNotNull(partyDao.getById(input.partyId)) { "طرف حساب پیدا نشد" }
            val prefix = settingsDao.get()?.invoicePrefix?.ifBlank { "ف" } ?: "ف"
            val sequence = if (kind == InvoiceKind.SALE) salesDao.countForDay(input.dateEpochDay) + 1 else purchaseDao.countForDay(input.dateEpochDay) + 1
            val datePart = PersianDate.format(input.dateEpochDay).replace("/", "")
            val number = "$prefix-$datePart-${"%03d".format(sequence)}"
            val invoiceId = if (kind == InvoiceKind.SALE) {
                salesDao.insertInvoice(SalesInvoiceEntity(invoiceNumber = number, partyId = input.partyId, dateEpochDay = input.dateEpochDay, subtotal = calculated.subtotal, discountAmount = calculated.discount, taxAmount = calculated.tax, totalAmount = calculated.total, paidAmount = input.paidAmount, balanceAmount = due, cashAccountId = input.cashAccountId, notes = input.notes.trim()))
            } else {
                purchaseDao.insertInvoice(PurchaseInvoiceEntity(invoiceNumber = number, partyId = input.partyId, dateEpochDay = input.dateEpochDay, subtotal = calculated.subtotal, discountAmount = calculated.discount, taxAmount = calculated.tax, totalAmount = calculated.total, paidAmount = input.paidAmount, balanceAmount = due, cashAccountId = input.cashAccountId, notes = input.notes.trim()))
            }
            val costs = mutableListOf<Long>()
            val unitCosts = mutableListOf<Long>()
            input.lines.forEach { line ->
                val product = requireNotNull(productDao.getById(line.productId)) { "یکی از کالاها حذف شده است" }
                if (kind == InvoiceKind.SALE) {
                    require(!product.trackInventory || product.stock >= line.quantity) { "موجودی «${product.name}» کافی نیست" }
                    unitCosts += product.purchasePrice
                    costs += if (product.trackInventory) (product.purchasePrice * line.quantity).roundToLong() else 0L
                }
            }
            if (kind == InvoiceKind.SALE) {
                salesDao.insertItems(input.lines.mapIndexed { index, line ->
                    val c = calculated.lines[index]
                    SalesInvoiceItemEntity(invoiceId = invoiceId, productId = line.productId, description = line.description.trim(), quantity = line.quantity, unitPrice = line.unitPrice, discountAmount = line.discountAmount, taxAmount = c.tax, totalAmount = c.total, unitCost = unitCosts[index], tracksInventory = requireNotNull(productDao.getById(line.productId)).trackInventory)
                })
            } else {
                purchaseDao.insertItems(input.lines.mapIndexed { index, line ->
                    val c = calculated.lines[index]
                    PurchaseInvoiceItemEntity(invoiceId = invoiceId, productId = line.productId, description = line.description.trim(), quantity = line.quantity, unitPrice = line.unitPrice, discountAmount = line.discountAmount, taxAmount = c.tax, totalAmount = c.total, tracksInventory = requireNotNull(productDao.getById(line.productId)).trackInventory)
                })
            }
            input.lines.forEach { line ->
                val delta = if (kind == InvoiceKind.SALE) -line.quantity else line.quantity
                val product = requireNotNull(productDao.getById(line.productId))
                if (product.trackInventory) {
                    productDao.updateStock(line.productId, delta)
                    productDao.insertInventoryTransaction(InventoryTransactionEntity(productId = line.productId, type = if (kind == InvoiceKind.SALE) "SALE" else "PURCHASE", quantity = delta, unitCost = if (kind == InvoiceKind.SALE) product.purchasePrice else line.unitPrice, referenceId = invoiceId, referenceType = if (kind == InvoiceKind.SALE) "SALE" else "PURCHASE", dateEpochDay = input.dateEpochDay, note = number))
                }
            }
            if (input.partyId != null && due > 0L) {
                val impact = if (kind == InvoiceKind.SALE) due else -due
                partyDao.updateBalance(input.partyId, impact)
                partyDao.insertTransaction(PartyTransactionEntity(partyId = input.partyId, type = if (kind == InvoiceKind.SALE) "SALE" else "PURCHASE", amount = impact, dateEpochDay = input.dateEpochDay, referenceId = invoiceId, referenceType = kind.name, note = number))
            }
            if (input.paidAmount > 0L) cashDao.updateBalance(requireNotNull(input.cashAccountId) { "برای پرداخت، حساب نقدی را انتخاب کنید" }, if (kind == InvoiceKind.SALE) input.paidAmount else -input.paidAmount)
            val baseLines = if (kind == InvoiceKind.SALE) listOf(
                JournalPoster.Line("11", debit = input.paidAmount, description = "دریافت نقدی $number"),
                JournalPoster.Line("13", debit = due, description = "باقیمانده فروش $number"),
                JournalPoster.Line("41", credit = calculated.total - calculated.tax, description = "فروش $number"),
                JournalPoster.Line("22", credit = calculated.tax, description = "مالیات فروش $number"),
                JournalPoster.Line("51", debit = costs.sum(), description = "بهای تمام‌شده $number"),
                JournalPoster.Line("12", credit = costs.sum(), description = "خروج موجودی $number")
            ) else listOf(
                JournalPoster.Line("12", debit = calculated.total, description = "خرید $number"),
                JournalPoster.Line("11", credit = input.paidAmount, description = "پرداخت نقدی $number"),
                JournalPoster.Line("21", credit = due, description = "باقیمانده خرید $number")
            )
            journal.post(kind.name, invoiceId, input.dateEpochDay, "ثبت خودکار فاکتور $number", baseLines)
            invoiceId
        }
    }

    override suspend fun cancelSale(invoiceId: Long): Result<Unit> = runCatching {
        db.withTransaction {
            val invoice = requireNotNull(salesDao.getInvoice(invoiceId)) { "فاکتور پیدا نشد" }
            require(invoice.status == "FINAL") { "فقط فاکتور نهایی قابل ابطال است" }
            val items = salesDao.getItems(invoiceId)
            salesDao.cancel(invoiceId)
            items.filter { it.tracksInventory }.forEach { item ->
                productDao.updateStock(item.productId, item.quantity)
                productDao.insertInventoryTransaction(InventoryTransactionEntity(productId = item.productId, type = "SALE_RETURN", quantity = item.quantity, unitCost = item.unitCost, referenceId = invoiceId, referenceType = "SALE_RETURN", dateEpochDay = PersianDate.today(), note = "ابطال ${invoice.invoiceNumber}"))
            }
            if (invoice.partyId != null && invoice.balanceAmount > 0) {
                partyDao.updateBalance(invoice.partyId, -invoice.balanceAmount)
                partyDao.insertTransaction(PartyTransactionEntity(partyId = invoice.partyId, type = "ADJUSTMENT", amount = -invoice.balanceAmount, dateEpochDay = PersianDate.today(), referenceId = invoiceId, referenceType = "SALE_CANCEL", note = "ابطال ${invoice.invoiceNumber}"))
            }
            if (invoice.paidAmount > 0 && invoice.cashAccountId != null) cashDao.updateBalance(invoice.cashAccountId, -invoice.paidAmount)
            val cost = items.sumOf { (it.unitCost * it.quantity).roundToLong() }
            journal.post("SALE_RETURN", invoiceId, PersianDate.today(), "ابطال فاکتور ${invoice.invoiceNumber}", listOf(
                JournalPoster.Line("41", debit = invoice.totalAmount - invoice.taxAmount), JournalPoster.Line("22", debit = invoice.taxAmount), JournalPoster.Line("11", credit = invoice.paidAmount), JournalPoster.Line("13", credit = invoice.balanceAmount),
                JournalPoster.Line("12", debit = cost), JournalPoster.Line("51", credit = cost)
            ))
        }
    }

    override suspend fun cancelPurchase(invoiceId: Long): Result<Unit> = runCatching {
        db.withTransaction {
            val invoice = requireNotNull(purchaseDao.getInvoice(invoiceId)) { "فاکتور پیدا نشد" }
            require(invoice.status == "FINAL") { "فقط فاکتور نهایی قابل ابطال است" }
            val items = purchaseDao.getItems(invoiceId)
            items.filter { it.tracksInventory }.forEach { item ->
                val product = requireNotNull(productDao.getById(item.productId))
                require(product.stock >= item.quantity) { "به‌دلیل فروش کالا، ابطال این خرید ممکن نیست" }
            }
            purchaseDao.cancel(invoiceId)
            items.filter { it.tracksInventory }.forEach { item ->
                productDao.updateStock(item.productId, -item.quantity)
                productDao.insertInventoryTransaction(InventoryTransactionEntity(productId = item.productId, type = "PURCHASE_RETURN", quantity = -item.quantity, unitCost = item.unitPrice, referenceId = invoiceId, referenceType = "PURCHASE_RETURN", dateEpochDay = PersianDate.today(), note = "ابطال ${invoice.invoiceNumber}"))
            }
            if (invoice.partyId != null && invoice.balanceAmount > 0) {
                partyDao.updateBalance(invoice.partyId, invoice.balanceAmount)
                partyDao.insertTransaction(PartyTransactionEntity(partyId = invoice.partyId, type = "ADJUSTMENT", amount = invoice.balanceAmount, dateEpochDay = PersianDate.today(), referenceId = invoiceId, referenceType = "PURCHASE_CANCEL", note = "ابطال ${invoice.invoiceNumber}"))
            }
            if (invoice.paidAmount > 0 && invoice.cashAccountId != null) cashDao.updateBalance(invoice.cashAccountId, invoice.paidAmount)
            journal.post("PURCHASE_RETURN", invoiceId, PersianDate.today(), "ابطال فاکتور ${invoice.invoiceNumber}", listOf(
                JournalPoster.Line("12", credit = invoice.totalAmount), JournalPoster.Line("11", debit = invoice.paidAmount), JournalPoster.Line("21", debit = invoice.balanceAmount)
            ))
        }
    }

    override suspend fun invoiceDocument(kind: InvoiceKind, invoiceId: Long): InvoiceDocument? = db.withTransaction {
        if (kind == InvoiceKind.SALE) {
            val invoice = salesDao.getInvoice(invoiceId) ?: return@withTransaction null
            val partyName = invoice.partyId?.let { partyDao.getById(it)?.name }
            val lines = salesDao.getItems(invoiceId).map { item ->
                InvoicePdfLine(item.description.ifBlank { productDao.getById(item.productId)?.name ?: "کالا" }, item.quantity, item.unitPrice, item.totalAmount)
            }
            InvoiceDocument(kind, invoice.invoiceNumber, partyName, invoice.dateEpochDay, lines, invoice.subtotal, invoice.discountAmount, invoice.taxAmount, invoice.totalAmount, invoice.paidAmount, invoice.balanceAmount, invoice.notes)
        } else {
            val invoice = purchaseDao.getInvoice(invoiceId) ?: return@withTransaction null
            val partyName = invoice.partyId?.let { partyDao.getById(it)?.name }
            val lines = purchaseDao.getItems(invoiceId).map { item ->
                InvoicePdfLine(item.description.ifBlank { productDao.getById(item.productId)?.name ?: "کالا" }, item.quantity, item.unitPrice, item.totalAmount)
            }
            InvoiceDocument(kind, invoice.invoiceNumber, partyName, invoice.dateEpochDay, lines, invoice.subtotal, invoice.discountAmount, invoice.taxAmount, invoice.totalAmount, invoice.paidAmount, invoice.balanceAmount, invoice.notes)
        }
    }

    private fun validateInvoice(input: InvoiceInput) {
        require(input.lines.isNotEmpty()) { "حداقل یک کالا به فاکتور اضافه کنید" }
        require(input.discountAmount >= 0 && input.paidAmount >= 0 && input.taxRate >= 0) { "مبالغ فاکتور نامعتبرند" }
        input.lines.forEach { require(it.quantity > 0 && it.unitPrice >= 0 && it.discountAmount >= 0) { "مقادیر یکی از ردیف‌ها نامعتبر است" } }
    }

    private data class CalculatedLine(val total: Long, val tax: Long)
    private data class Calculated(val subtotal: Long, val discount: Long, val tax: Long, val total: Long, val lines: List<CalculatedLine>)
    private fun calculate(input: InvoiceInput): Calculated {
        val subtotal = input.lines.sumOf { (it.quantity * it.unitPrice).roundToLong() }
        val lineDiscount = input.lines.sumOf { it.discountAmount }
        val discount = lineDiscount + input.discountAmount
        require(discount <= subtotal) { "تخفیف نمی‌تواند بیشتر از جمع فاکتور باشد" }
        val netBeforeTax = subtotal - discount
        val tax = if (input.taxEnabled) (netBeforeTax * input.taxRate / 100).roundToLong() else 0L
        val lines = input.lines.map { line ->
            val lineBase = (line.quantity * line.unitPrice).roundToLong() - line.discountAmount
            val lineTax = if (input.taxEnabled && netBeforeTax > 0) (tax * lineBase.toDouble() / netBeforeTax).roundToLong() else 0L
            CalculatedLine(lineBase + lineTax, lineTax)
        }
        return Calculated(subtotal, discount, tax, netBeforeTax + tax, lines)
    }
}

class CashRepositoryImpl @Inject constructor(
    private val db: HesabyarDatabase,
    private val dao: CashDao,
    private val partyDao: PartyDao,
    accountingDao: AccountingDao
) : CashRepository {
    private val journal = JournalPoster(accountingDao)
    override val accounts = dao.observeAccounts()
    override val cashBalance = dao.observeCashBalance()
    override val bankBalance = dao.observeBankBalance()
    override val receipts = dao.observeReceipts()
    override val payments = dao.observePayments()

    override suspend fun saveAccount(account: CashAccountEntity): Result<Long> = runCatching {
        require(account.name.trim().isNotEmpty()) { "نام حساب را وارد کنید" }
        require(account.type in setOf("CASH", "BANK")) { "نوع حساب نامعتبر است" }
        if (account.id == 0L) dao.insertAccount(account.copy(name = account.name.trim(), balance = account.openingBalance))
        else { dao.updateAccount(account.copy(name = account.name.trim(), updatedAt = System.currentTimeMillis())); account.id }
    }

    override suspend fun receive(receipt: ReceiptEntity): Result<Long> = runCatching {
        require(receipt.amount > 0) { "مبلغ دریافت را وارد کنید" }
        db.withTransaction {
            requireNotNull(dao.getAccount(receipt.cashAccountId)) { "حساب نقدی پیدا نشد" }
            if (receipt.partyId != null) requireNotNull(partyDao.getById(receipt.partyId)) { "طرف حساب پیدا نشد" }
            val id = dao.insertReceipt(receipt)
            dao.updateBalance(receipt.cashAccountId, receipt.amount)
            if (receipt.partyId != null) {
                partyDao.updateBalance(receipt.partyId, -receipt.amount)
                partyDao.insertTransaction(PartyTransactionEntity(partyId = receipt.partyId, type = "RECEIPT", amount = -receipt.amount, dateEpochDay = receipt.dateEpochDay, referenceId = id, referenceType = "RECEIPT", note = receipt.note))
            }
            journal.post("RECEIPT", id, receipt.dateEpochDay, "دریافت وجه", listOf(JournalPoster.Line("11", debit = receipt.amount), JournalPoster.Line(if (receipt.partyId != null) "13" else "41", credit = receipt.amount)))
            id
        }
    }

    override suspend fun pay(payment: PaymentEntity): Result<Long> = runCatching {
        require(payment.amount > 0) { "مبلغ پرداخت را وارد کنید" }
        db.withTransaction {
            requireNotNull(dao.getAccount(payment.cashAccountId)) { "حساب نقدی پیدا نشد" }
            if (payment.partyId != null) requireNotNull(partyDao.getById(payment.partyId)) { "طرف حساب پیدا نشد" }
            val id = dao.insertPayment(payment)
            dao.updateBalance(payment.cashAccountId, -payment.amount)
            if (payment.partyId != null) {
                partyDao.updateBalance(payment.partyId, payment.amount)
                partyDao.insertTransaction(PartyTransactionEntity(partyId = payment.partyId, type = "PAYMENT", amount = payment.amount, dateEpochDay = payment.dateEpochDay, referenceId = id, referenceType = "PAYMENT", note = payment.note))
            }
            journal.post("PAYMENT", id, payment.dateEpochDay, "پرداخت وجه", listOf(JournalPoster.Line(if (payment.partyId != null) "21" else "52", debit = payment.amount), JournalPoster.Line("11", credit = payment.amount)))
            id
        }
    }

    override suspend fun addExpense(expense: ExpenseEntity): Result<Long> = runCatching {
        require(expense.title.trim().isNotEmpty() && expense.amount > 0) { "عنوان و مبلغ هزینه را وارد کنید" }
        db.withTransaction {
            requireNotNull(dao.getAccount(expense.cashAccountId)) { "حساب نقدی پیدا نشد" }
            val id = dao.insertExpense(expense.copy(title = expense.title.trim()))
            dao.updateBalance(expense.cashAccountId, -expense.amount)
            journal.post("EXPENSE", id, expense.dateEpochDay, expense.title, listOf(JournalPoster.Line("52", debit = expense.amount), JournalPoster.Line("11", credit = expense.amount)))
            id
        }
    }

    override suspend fun addIncome(income: IncomeEntity): Result<Long> = runCatching {
        require(income.title.trim().isNotEmpty() && income.amount > 0) { "عنوان و مبلغ درآمد را وارد کنید" }
        db.withTransaction {
            requireNotNull(dao.getAccount(income.cashAccountId)) { "حساب نقدی پیدا نشد" }
            val id = dao.insertIncome(income.copy(title = income.title.trim()))
            dao.updateBalance(income.cashAccountId, income.amount)
            journal.post("INCOME", id, income.dateEpochDay, income.title, listOf(JournalPoster.Line("11", debit = income.amount), JournalPoster.Line("41", credit = income.amount)))
            id
        }
    }

    override suspend fun transfer(transfer: CashTransferEntity): Result<Long> = runCatching {
        require(transfer.amount > 0 && transfer.fromAccountId != transfer.toAccountId) { "اطلاعات انتقال وجه نامعتبر است" }
        db.withTransaction {
            requireNotNull(dao.getAccount(transfer.fromAccountId)) { "حساب مبدا پیدا نشد" }
            requireNotNull(dao.getAccount(transfer.toAccountId)) { "حساب مقصد پیدا نشد" }
            val id = dao.insertTransfer(transfer)
            dao.updateBalance(transfer.fromAccountId, -transfer.amount)
            dao.updateBalance(transfer.toAccountId, transfer.amount)
            journal.post("TRANSFER", id, transfer.dateEpochDay, "انتقال وجه", listOf(JournalPoster.Line("11", debit = transfer.amount, description = "مقصد"), JournalPoster.Line("11", credit = transfer.amount, description = "مبدا")))
            id
        }
    }
}

class AccountingRepositoryImpl @Inject constructor(
    private val db: HesabyarDatabase,
    private val dao: AccountingDao
) : AccountingRepository {
    override val accounts = dao.observeAccounts()
    override val entries = dao.observeEntries()
    override val trialBalance = dao.observeTrialBalance()
    override suspend fun saveAccount(account: AccountEntity): Result<Long> = runCatching {
        require(account.code.trim().isNotEmpty() && account.name.trim().isNotEmpty()) { "کد و نام حساب را وارد کنید" }
        require(account.type in setOf("ASSET", "LIABILITY", "EQUITY", "REVENUE", "EXPENSE")) { "گروه حساب نامعتبر است" }
        if (account.id == 0L) dao.insertAccount(account.copy(code = account.code.trim(), name = account.name.trim()))
        else { dao.updateAccount(account.copy(code = account.code.trim(), name = account.name.trim(), updatedAt = System.currentTimeMillis())); account.id }
    }
    override suspend fun saveManualEntry(input: JournalInput): Result<Long> = runCatching {
        require(input.description.trim().isNotEmpty()) { "شرح سند را وارد کنید" }
        require(input.lines.size >= 2) { "سند باید حداقل دو ردیف داشته باشد" }
        require(input.lines.sumOf { it.debit } == input.lines.sumOf { it.credit }) { "سند تراز نیست" }
        require(input.lines.sumOf { it.debit } > 0) { "مبلغ سند باید بیشتر از صفر باشد" }
        db.withTransaction {
            val id = dao.insertEntry(JournalEntryEntity(entryNumber = "MANUAL-${input.dateEpochDay}-${dao.countForDay(input.dateEpochDay) + 1}", dateEpochDay = input.dateEpochDay, description = input.description.trim()))
            dao.insertItems(input.lines.map { line ->
                require(line.debit >= 0 && line.credit >= 0 && !(line.debit > 0 && line.credit > 0)) { "ردیف سند نامعتبر است" }
                requireNotNull(dao.getAccount(line.accountId)) { "یکی از حساب‌های سند پیدا نشد" }
                JournalItemEntity(journalEntryId = id, accountId = line.accountId, debit = line.debit, credit = line.credit, description = line.description)
            })
            id
        }
    }
    override suspend fun deleteManualEntry(id: Long): Result<Unit> = runCatching { dao.deleteManualEntry(id) }
    override fun ledger(accountId: Long, from: Long, to: Long) = dao.observeLedger(accountId, from, to)
}

class ReportsRepositoryImpl @Inject constructor(
    salesDao: SalesDao,
    purchaseDao: PurchaseDao,
    cashDao: CashDao,
    reportsDao: ReportsDao
) : ReportsRepository {
    override fun sales(from: Long, to: Long) = salesDao.observeTotalBetween(from, to)
    override fun purchases(from: Long, to: Long) = purchaseDao.observeTotalBetween(from, to)
    override fun expenses(from: Long, to: Long) = cashDao.observeExpenses(from, to)
    override fun incomes(from: Long, to: Long) = cashDao.observeIncomes(from, to)
    override fun profitLoss(from: Long, to: Long): Flow<ProfitLossSummary> = combine(
        salesDao.observeNetTotalBetween(from, to), reportsDao.observeCostOfGoods(from, to), expenses(from, to), incomes(from, to)
    ) { sales, costs, expenses, incomes -> ProfitLossSummary(sales, costs, expenses, incomes) }
}
