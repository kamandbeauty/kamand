package ir.factoryar.core.data.di

import android.content.Context
import androidx.room.Room
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import ir.factoryar.core.database.FactorYarDatabase
import ir.factoryar.core.database.dao.BusinessDao
import ir.factoryar.core.database.dao.CustomerDao
import ir.factoryar.core.database.dao.ExpenseDao
import ir.factoryar.core.database.dao.InvoiceDao
import ir.factoryar.core.database.dao.ProductDao
import ir.factoryar.core.database.dao.RecurringDao
import ir.factoryar.core.database.migration.ALL_MIGRATIONS
import ir.factoryar.core.data.repository.BackupRepositoryImpl
import ir.factoryar.core.data.repository.BusinessRepositoryImpl
import ir.factoryar.core.data.repository.CustomerRepositoryImpl
import ir.factoryar.core.data.repository.DebtorRepositoryImpl
import ir.factoryar.core.data.repository.ExpenseRepositoryImpl
import ir.factoryar.core.data.repository.InvoiceRepositoryImpl
import ir.factoryar.core.data.repository.ProductRepositoryImpl
import ir.factoryar.core.data.repository.RecurringRepositoryImpl
import ir.factoryar.core.data.repository.SettingsRepositoryImpl
import ir.factoryar.core.datastore.SettingsDataStore
import ir.factoryar.core.domain.repository.BackupRepository
import ir.factoryar.core.domain.repository.BusinessRepository
import ir.factoryar.core.domain.repository.CustomerRepository
import ir.factoryar.core.domain.repository.DebtorRepository
import ir.factoryar.core.domain.repository.ExpenseRepository
import ir.factoryar.core.domain.repository.InvoiceRepository
import ir.factoryar.core.domain.repository.PremiumRepository
import ir.factoryar.core.domain.repository.ProductRepository
import ir.factoryar.core.domain.repository.ProfitRepository
import ir.factoryar.core.domain.repository.RecurringRepository
import ir.factoryar.core.domain.repository.SettingsRepository
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import net.zetetic.database.sqlcipher.SupportOpenHelperFactory
import java.security.SecureRandom
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    /**
     * کلید رمزنگاری SQLCipher: یک‌بار به‌صورت تصادفی تولید و در DataStore ذخیره می‌شود.
     */
    @Provides
    @Singleton
    fun provideDbPassphrase(ds: SettingsDataStore): ByteArray = runBlocking {
        val saved = ds.get(SettingsDataStore.Keys.DB_PASSPHRASE, "").first()
        if (saved.isNotBlank()) {
            saved.toByteArray(Charsets.UTF_8)
        } else {
            val bytes = ByteArray(32).also { SecureRandom().nextBytes(it) }
            val hex = bytes.joinToString("") { "%02x".format(it) }
            ds.set(SettingsDataStore.Keys.DB_PASSPHRASE, hex)
            hex.toByteArray(Charsets.UTF_8)
        }
    }

    /**
     * کتابخانهٔ نیتیو SQLCipher باید پیش از هر استفاده صریحاً بارگذاری شود.
     * در نسخهٔ sqlcipher-android (برخلاف android-database-sqlcipher قدیمی)
     * این کار خودکار انجام نمی‌شود.
     */
    private val nativeLibraryLoaded: Boolean by lazy {
        runCatching { System.loadLibrary("sqlcipher") }.isSuccess
    }

    @Provides
    @Singleton
    fun provideDatabase(
        @ApplicationContext context: Context,
        passphrase: ByteArray,
    ): FactorYarDatabase {
        check(nativeLibraryLoaded) { "بارگذاری کتابخانهٔ SQLCipher ناموفق بود" }
        return Room.databaseBuilder(
            context,
            FactorYarDatabase::class.java,
            FactorYarDatabase.DATABASE_NAME,
        )
            .openHelperFactory(SupportOpenHelperFactory(passphrase))
        // مهاجرت واقعی نسخه ۱ → ۲ (افزودن انبار و هزینه‌ها) بدون از دست رفتن داده کاربر
            .addMigrations(*ALL_MIGRATIONS)
            .build()
    }

    @Provides
    fun provideCustomerDao(db: FactorYarDatabase): CustomerDao = db.customerDao()

    @Provides
    fun provideInvoiceDao(db: FactorYarDatabase): InvoiceDao = db.invoiceDao()

    @Provides
    fun provideRecurringDao(db: FactorYarDatabase): RecurringDao = db.recurringDao()

    @Provides
    fun provideBusinessDao(db: FactorYarDatabase): BusinessDao = db.businessDao()

    @Provides
    fun provideProductDao(db: FactorYarDatabase): ProductDao = db.productDao()

    @Provides
    fun provideExpenseDao(db: FactorYarDatabase): ExpenseDao = db.expenseDao()
}

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    abstract fun bindCustomerRepository(impl: CustomerRepositoryImpl): CustomerRepository

    @Binds
    abstract fun bindInvoiceRepository(impl: InvoiceRepositoryImpl): InvoiceRepository

    @Binds
    abstract fun bindRecurringRepository(impl: RecurringRepositoryImpl): RecurringRepository

    @Binds
    abstract fun bindBusinessRepository(impl: BusinessRepositoryImpl): BusinessRepository

    @Binds
    abstract fun bindSettingsRepository(impl: SettingsRepositoryImpl): SettingsRepository

    @Binds
    abstract fun bindPremiumRepository(impl: SettingsRepositoryImpl): PremiumRepository

    @Binds
    abstract fun bindBackupRepository(impl: BackupRepositoryImpl): BackupRepository

    @Binds
    abstract fun bindProductRepository(impl: ProductRepositoryImpl): ProductRepository

    @Binds
    abstract fun bindExpenseRepository(impl: ExpenseRepositoryImpl): ExpenseRepository

    @Binds
    abstract fun bindProfitRepository(impl: ExpenseRepositoryImpl): ProfitRepository

    @Binds
    abstract fun bindDebtorRepository(impl: DebtorRepositoryImpl): DebtorRepository
}
