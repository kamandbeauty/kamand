package com.modir.forushgah.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.modir.forushgah.data.local.converter.EnumConverters
import com.modir.forushgah.data.local.converter.MoneyConverters
import com.modir.forushgah.data.local.dao.*
import com.modir.forushgah.data.local.entity.*

@Database(
    entities = [
        ProductEntity::class,
        CategoryEntity::class,
        InventoryMovementEntity::class,
        CustomerEntity::class,
        SupplierEntity::class,
        OrderEntity::class,
        OrderItemEntity::class,
        PaymentEntity::class,
        SalesChannelEntity::class,
        ShippingProviderEntity::class,
        ExpenseEntity::class,
        ExpenseCategoryEntity::class,
        EmployeeEntity::class,
        EmployeeCommissionRuleEntity::class,
        ReceivableEntity::class,
        PayableEntity::class,
        SupplierPaymentEntity::class,
        OrderReturnEntity::class,
        FinancialTransactionEntity::class,
        SettlementPlanEntity::class,
        InstallmentEntity::class,
        StoreProfileEntity::class,
    ],
    version = 2, // Phase 2: added Customer/Supplier isActive+updatedAt, Category isActive,
    // InventoryMovement reference/before-after fields. fallbackToDestructiveMigration is
    // still in effect pre-release (see DatabaseModule), so no Migration object needed yet.
    exportSchema = true,
)
@TypeConverters(MoneyConverters::class, EnumConverters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun productDao(): ProductDao
    abstract fun categoryDao(): CategoryDao
    abstract fun inventoryMovementDao(): InventoryMovementDao
    abstract fun customerDao(): CustomerDao
    abstract fun supplierDao(): SupplierDao
    abstract fun orderDao(): OrderDao
    abstract fun paymentDao(): PaymentDao
    abstract fun salesChannelDao(): SalesChannelDao
    abstract fun shippingProviderDao(): ShippingProviderDao
    abstract fun expenseDao(): ExpenseDao
    abstract fun expenseCategoryDao(): ExpenseCategoryDao
    abstract fun employeeDao(): EmployeeDao
    abstract fun receivableDao(): ReceivableDao
    abstract fun payableDao(): PayableDao
    abstract fun supplierPaymentDao(): SupplierPaymentDao
    abstract fun orderReturnDao(): OrderReturnDao
    abstract fun financialTransactionDao(): FinancialTransactionDao
    abstract fun settlementPlanDao(): SettlementPlanDao
    abstract fun storeProfileDao(): StoreProfileDao

    companion object {
        const val DATABASE_NAME = "modir_forushgah.db"
    }
}
