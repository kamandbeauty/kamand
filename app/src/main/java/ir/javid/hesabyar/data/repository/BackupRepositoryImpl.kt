package ir.javid.hesabyar.data.repository

import android.content.Context
import androidx.room.withTransaction
import dagger.hilt.android.qualifiers.ApplicationContext
import ir.javid.hesabyar.data.local.HesabyarDatabase
import ir.javid.hesabyar.domain.repository.BackupRepository
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import javax.inject.Inject

/** Device-only, raw SQLite backup. Export is checkpointed first so no WAL data is lost. */
class BackupRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    private val database: HesabyarDatabase
) : BackupRepository {
    private val databaseFile: File get() = context.getDatabasePath(HesabyarDatabase.DATABASE_NAME)

    override suspend fun exportTo(output: OutputStream): Result<Unit> = runCatching {
        database.withTransaction {
            database.openHelper.writableDatabase.execSQL("PRAGMA wal_checkpoint(FULL)")
            require(databaseFile.exists()) { "فایل اطلاعات پیدا نشد" }
            databaseFile.inputStream().use { source -> source.copyTo(output) }
            output.flush()
        }
    }

    override suspend fun restoreFrom(input: InputStream): Result<Unit> = runCatching {
        val temporary = File.createTempFile("hesabyar_restore_", ".db", context.cacheDir)
        try {
            temporary.outputStream().use { destination -> input.copyTo(destination) }
            val header = ByteArray(16)
            temporary.inputStream().use { it.read(header) }
            require(String(header, Charsets.US_ASCII).startsWith("SQLite format 3")) { "فایل انتخاب‌شده یک نسخه پشتیبان معتبر نیست" }
            database.close()
            databaseFile.parentFile?.mkdirs()
            val replacement = File(databaseFile.parentFile, "${databaseFile.name}.restoring")
            temporary.copyTo(replacement, overwrite = true)
            if (databaseFile.exists()) databaseFile.delete()
            File("${databaseFile.path}-wal").delete()
            File("${databaseFile.path}-shm").delete()
            require(replacement.renameTo(databaseFile)) { "جایگزینی فایل پشتیبان انجام نشد" }
        } finally {
            temporary.delete()
        }
    }
}
