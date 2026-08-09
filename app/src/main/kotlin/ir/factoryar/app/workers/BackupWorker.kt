package ir.factoryar.app.workers

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import ir.factoryar.app.notifications.NotificationHelper
import ir.factoryar.core.database.FactorYarDatabase
import ir.factoryar.core.domain.repository.SettingsRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** پشتیبان‌گیری هفتگی خودکار محلی (ZIP) وقتی در تنظیمات فعال باشد */
@HiltWorker
class BackupWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted params: WorkerParameters,
    private val settingsRepository: SettingsRepository,
    private val db: FactorYarDatabase,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            if (!settingsRepository.settings.first().weeklyBackupEnabled) {
                return@withContext Result.success()
            }
            val dbFile = applicationContext.getDatabasePath(FactorYarDatabase.DATABASE_NAME)
            if (!dbFile.exists()) return@withContext Result.success()

            val dir = File(
                applicationContext.getExternalFilesDir(null) ?: applicationContext.filesDir,
                "backups",
            ).apply { mkdirs() }
            val file = File(dir, "factoryar_auto_backup.zip")
            runCatching { db.query("PRAGMA wal_checkpoint(FULL)", emptyArray()).close() }
            ZipOutputStream(FileOutputStream(file)).use { zip ->
                zip.putNextEntry(ZipEntry("db/${dbFile.name}"))
                dbFile.inputStream().use { it.copyTo(zip) }
                zip.closeEntry()
            }
            NotificationHelper.notifyBackupDone(applicationContext)
            Result.success()
        } catch (t: Throwable) {
            Result.retry()
        }
    }

    companion object {
        private const val WORK_NAME = "factoryar_backup_weekly"

        fun enqueue(workManager: WorkManager) {
            val request = PeriodicWorkRequestBuilder<BackupWorker>(7, TimeUnit.DAYS).build()
            workManager.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}
