package ir.factoryar.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import ir.factoryar.core.database.entity.BusinessProfileEntity
import ir.factoryar.core.database.entity.RecurringInvoiceEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface RecurringDao {

    @Query("SELECT * FROM recurring_invoices ORDER BY nextRunDate ASC")
    fun observeAll(): Flow<List<RecurringInvoiceEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: RecurringInvoiceEntity): Long

    @Query("DELETE FROM recurring_invoices WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("UPDATE recurring_invoices SET active = :active WHERE id = :id")
    suspend fun setActive(id: Long, active: Boolean)

    @Query("SELECT * FROM recurring_invoices WHERE active = 1 AND nextRunDate <= :untilMillis")
    suspend fun dueItems(untilMillis: Long): List<RecurringInvoiceEntity>

    @Query("UPDATE recurring_invoices SET nextRunDate = :nextRun WHERE id = :id")
    suspend fun updateNextRun(id: Long, nextRun: Long)
}

@Dao
interface BusinessDao {

    @Query("SELECT * FROM business_profiles WHERE isActive = 1 LIMIT 1")
    fun observeActive(): Flow<BusinessProfileEntity?>

    @Query("SELECT * FROM business_profiles WHERE isActive = 1 LIMIT 1")
    suspend fun getActive(): BusinessProfileEntity?

    @Query("SELECT * FROM business_profiles ORDER BY id ASC")
    fun observeAll(): Flow<List<BusinessProfileEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: BusinessProfileEntity): Long

    @Query("UPDATE business_profiles SET isActive = 0")
    suspend fun clearActive()

    @Query("UPDATE business_profiles SET isActive = 1 WHERE id = :id")
    suspend fun setActive(id: Long)
}
