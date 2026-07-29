package ir.factoryar.core.database

import androidx.room.Database
import androidx.room.RoomDatabase
import ir.factoryar.core.database.dao.BusinessDao
import ir.factoryar.core.database.dao.CustomerDao
import ir.factoryar.core.database.dao.ExpenseDao
import ir.factoryar.core.database.dao.InvoiceDao
import ir.factoryar.core.database.dao.ProductDao
import ir.factoryar.core.database.dao.RecurringDao
import ir.factoryar.core.database.entity.BusinessProfileEntity
import ir.factoryar.core.database.entity.CustomerEntity
import ir.factoryar.core.database.entity.ExpenseCategoryEntity
import ir.factoryar.core.database.entity.ExpenseEntity
import ir.factoryar.core.database.entity.InvoiceEntity
import ir.factoryar.core.database.entity.InvoiceItemEntity
import ir.factoryar.core.database.entity.ProductCategoryEntity
import ir.factoryar.core.database.entity.ProductEntity
import ir.factoryar.core.database.entity.RecurringInvoiceEntity
import ir.factoryar.core.database.entity.StockMovementEntity

@Database(
    entities = [
        CustomerEntity::class,
        InvoiceEntity::class,
        InvoiceItemEntity::class,
        RecurringInvoiceEntity::class,
        BusinessProfileEntity::class,
        // نسخه ۲: انبار و هزینه‌ها
        ProductEntity::class,
        ProductCategoryEntity::class,
        StockMovementEntity::class,
        ExpenseEntity::class,
        ExpenseCategoryEntity::class,
    ],
    version = 2,
    exportSchema = true,
)
abstract class FactorYarDatabase : RoomDatabase() {

    abstract fun customerDao(): CustomerDao
    abstract fun invoiceDao(): InvoiceDao
    abstract fun recurringDao(): RecurringDao
    abstract fun businessDao(): BusinessDao
    abstract fun productDao(): ProductDao
    abstract fun expenseDao(): ExpenseDao

    companion object {
        const val DATABASE_NAME = "factoryar.db"
    }
}
