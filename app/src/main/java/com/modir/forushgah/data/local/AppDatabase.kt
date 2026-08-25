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
        OrderReturnItemEntity::class,
        RefundEntity::class,
        PaymentMethodEntity::class,
        FinancialTransactionEntity::class,
        SettlementPlanEntity::class,
        InstallmentEntity::class,
        StoreProfileEntity::class,
    ],
    version = 7, // Phase 4.2: standalone expense workflow — expenses gains
    // deletedAt (soft delete: a deleted expense disappears from active lists
    // but keeps its row and full financial history) and financial_transactions
    // gains a (referenceType, referenceId) index for standalone-expense events.
    // The ExpenseGroup enum set also changes (PACKAGING/SHIPPING/PURCHASE/
    // RENT/SALARY/UTILITIES/OTHER); pre-release destructive migration covers it.
    // fallbackToDestructiveMigration is still in effect pre-release (see
    // DatabaseModule), so no Migration object needed yet.
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
    abstract fun refundDao(): RefundDao
    abstract fun paymentMethodDao(): PaymentMethodDao
    abstract fun financialTransactionDao(): FinancialTransactionDao
    abstract fun settlementPlanDao(): SettlementPlanDao
    abstract fun storeProfileDao(): StoreProfileDao

    companion object {
        const val DATABASE_NAME = "modir_forushgah.db"
    }
}
