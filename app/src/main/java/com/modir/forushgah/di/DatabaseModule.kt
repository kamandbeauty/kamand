package com.modir.forushgah.di

import android.content.Context
import androidx.room.Room
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.dao.*
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, AppDatabase.DATABASE_NAME)
            // Phase 1 has no migrations yet; fallbackToDestructiveMigration is
            // ONLY acceptable pre-release. Must be replaced with real
            // Migration objects before the first production release.
            .fallbackToDestructiveMigration()
            .build()

    @Provides fun provideProductDao(db: AppDatabase): ProductDao = db.productDao()
    @Provides fun provideCategoryDao(db: AppDatabase): CategoryDao = db.categoryDao()
    @Provides fun provideInventoryMovementDao(db: AppDatabase): InventoryMovementDao = db.inventoryMovementDao()
    @Provides fun provideCustomerDao(db: AppDatabase): CustomerDao = db.customerDao()
    @Provides fun provideSupplierDao(db: AppDatabase): SupplierDao = db.supplierDao()
    @Provides fun provideOrderDao(db: AppDatabase): OrderDao = db.orderDao()
    @Provides fun providePaymentDao(db: AppDatabase): PaymentDao = db.paymentDao()
    @Provides fun provideSalesChannelDao(db: AppDatabase): SalesChannelDao = db.salesChannelDao()
    @Provides fun provideShippingProviderDao(db: AppDatabase): ShippingProviderDao = db.shippingProviderDao()
    @Provides fun provideExpenseDao(db: AppDatabase): ExpenseDao = db.expenseDao()
    @Provides fun provideExpenseCategoryDao(db: AppDatabase): ExpenseCategoryDao = db.expenseCategoryDao()
    @Provides fun provideEmployeeDao(db: AppDatabase): EmployeeDao = db.employeeDao()
    @Provides fun provideReceivableDao(db: AppDatabase): ReceivableDao = db.receivableDao()
    @Provides fun providePayableDao(db: AppDatabase): PayableDao = db.payableDao()
    @Provides fun provideSupplierPaymentDao(db: AppDatabase): SupplierPaymentDao = db.supplierPaymentDao()
    @Provides fun provideOrderReturnDao(db: AppDatabase): OrderReturnDao = db.orderReturnDao()
    @Provides fun provideRefundDao(db: AppDatabase): RefundDao = db.refundDao()
    @Provides fun providePaymentMethodDao(db: AppDatabase): PaymentMethodDao = db.paymentMethodDao()
    @Provides fun provideFinancialTransactionDao(db: AppDatabase): FinancialTransactionDao = db.financialTransactionDao()
    @Provides fun provideSettlementPlanDao(db: AppDatabase): SettlementPlanDao = db.settlementPlanDao()
    @Provides fun provideStoreProfileDao(db: AppDatabase): StoreProfileDao = db.storeProfileDao()
}
