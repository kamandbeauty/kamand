package ir.javid.hesabyar.di

import android.content.Context
import androidx.room.Room
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import ir.javid.hesabyar.data.local.HesabyarDatabase
import ir.javid.hesabyar.data.repository.*
import ir.javid.hesabyar.domain.repository.*
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides @Singleton
    fun provideDatabase(@ApplicationContext context: Context): HesabyarDatabase =
        Room.databaseBuilder(context, HesabyarDatabase::class.java, HesabyarDatabase.DATABASE_NAME)
            .addCallback(HesabyarDatabase.seedCallback)
            .build()

    @Provides fun provideSettingsDao(db: HesabyarDatabase) = db.settingsDao()
    @Provides fun provideProductDao(db: HesabyarDatabase) = db.productDao()
    @Provides fun providePartyDao(db: HesabyarDatabase) = db.partyDao()
    @Provides fun provideSalesDao(db: HesabyarDatabase) = db.salesDao()
    @Provides fun providePurchaseDao(db: HesabyarDatabase) = db.purchaseDao()
    @Provides fun provideCashDao(db: HesabyarDatabase) = db.cashDao()
    @Provides fun provideAccountingDao(db: HesabyarDatabase) = db.accountingDao()
    @Provides fun provideDashboardDao(db: HesabyarDatabase) = db.dashboardDao()
    @Provides fun provideReportsDao(db: HesabyarDatabase) = db.reportsDao()
}

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds @Singleton abstract fun dashboard(impl: DashboardRepositoryImpl): DashboardRepository
    @Binds @Singleton abstract fun settings(impl: SettingsRepositoryImpl): SettingsRepository
    @Binds @Singleton abstract fun products(impl: ProductRepositoryImpl): ProductRepository
    @Binds @Singleton abstract fun parties(impl: PartyRepositoryImpl): PartyRepository
    @Binds @Singleton abstract fun invoices(impl: InvoiceRepositoryImpl): InvoiceRepository
    @Binds @Singleton abstract fun cash(impl: CashRepositoryImpl): CashRepository
    @Binds @Singleton abstract fun accounting(impl: AccountingRepositoryImpl): AccountingRepository
    @Binds @Singleton abstract fun reports(impl: ReportsRepositoryImpl): ReportsRepository
    @Binds @Singleton abstract fun backup(impl: BackupRepositoryImpl): BackupRepository
}
