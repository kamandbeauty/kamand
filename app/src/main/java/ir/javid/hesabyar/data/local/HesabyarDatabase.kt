package ir.javid.hesabyar.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import ir.javid.hesabyar.data.local.dao.*
import ir.javid.hesabyar.data.local.entity.*

/**
 * Local source of truth. No screen accesses a DAO directly: repositories own all
 * business transactions so a future sync source can be added without changing UI.
 */
@Database(
    entities = [
        AppSettingsEntity::class, ProductCategoryEntity::class, ProductEntity::class,
        InventoryTransactionEntity::class, PartyEntity::class, PartyTransactionEntity::class,
        SalesInvoiceEntity::class, SalesInvoiceItemEntity::class,
        PurchaseInvoiceEntity::class, PurchaseInvoiceItemEntity::class,
        CashAccountEntity::class, ReceiptEntity::class, PaymentEntity::class,
        ExpenseEntity::class, IncomeEntity::class, CashTransferEntity::class,
        AccountEntity::class, JournalEntryEntity::class, JournalItemEntity::class,
        LicenseEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class HesabyarDatabase : RoomDatabase() {
    abstract fun settingsDao(): SettingsDao
    abstract fun productDao(): ProductDao
    abstract fun partyDao(): PartyDao
    abstract fun salesDao(): SalesDao
    abstract fun purchaseDao(): PurchaseDao
    abstract fun cashDao(): CashDao
    abstract fun accountingDao(): AccountingDao
    abstract fun dashboardDao(): DashboardDao
    abstract fun reportsDao(): ReportsDao

    companion object {
        const val DATABASE_NAME = "hesabyar_javid.db"

        /** Basic chart of accounts makes automatic double-entry bookkeeping usable immediately. */
        val seedCallback = object : Callback() {
            override fun onCreate(db: SupportSQLiteDatabase) {
                super.onCreate(db)
                db.execSQL("INSERT INTO app_settings (id, businessName, ownerName, phone, address, currency, taxEnabled, taxRate, invoicePrefix, updatedAt) VALUES (1, '', '', '', '', 'TOMAN', 0, 10.0, 'ف', ${System.currentTimeMillis()})")
                db.execSQL("INSERT INTO licenses (id, tier, activatedAt, expiresAt, token) VALUES (1, 'FREE', NULL, NULL, '')")
                db.execSQL("INSERT INTO cash_accounts (name, type, bankName, cardNumber, accountNumber, openingBalance, balance, isActive, createdAt, updatedAt) VALUES ('صندوق اصلی', 'CASH', '', '', '', 0, 0, 1, ${System.currentTimeMillis()}, ${System.currentTimeMillis()})")
                val accounts = listOf(
                    Triple("1", "دارایی‌ها", "ASSET"), Triple("11", "صندوق و بانک", "ASSET"), Triple("12", "موجودی کالا", "ASSET"), Triple("13", "حساب‌های دریافتنی", "ASSET"),
                    Triple("2", "بدهی‌ها", "LIABILITY"), Triple("21", "حساب‌های پرداختنی", "LIABILITY"), Triple("22", "مالیات پرداختنی", "LIABILITY"),
                    Triple("3", "سرمایه", "EQUITY"), Triple("4", "درآمدها", "REVENUE"), Triple("41", "فروش کالا و خدمات", "REVENUE"),
                    Triple("5", "هزینه‌ها", "EXPENSE"), Triple("51", "بهای تمام‌شده کالای فروش‌رفته", "EXPENSE"), Triple("52", "هزینه‌های عملیاتی", "EXPENSE")
                )
                accounts.forEach { (code, name, type) ->
                    val level = if (code.length == 1) 1 else 2
                    db.execSQL("INSERT INTO accounts (code, name, type, parentId, level, isSystem, isActive, createdAt, updatedAt) VALUES ('$code', '$name', '$type', NULL, $level, 1, 1, ${System.currentTimeMillis()}, ${System.currentTimeMillis()})")
                }
            }
        }
    }
}
