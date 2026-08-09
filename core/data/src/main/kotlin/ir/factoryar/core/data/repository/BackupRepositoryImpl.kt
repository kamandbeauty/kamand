package ir.factoryar.core.data.repository

import android.content.Context
import android.net.Uri
import dagger.hilt.android.qualifiers.ApplicationContext
import ir.factoryar.core.common.util.DateUtils
import ir.factoryar.core.database.FactorYarDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import javax.inject.Inject
import javax.inject.Singleton

/**
 * پشتیبان‌گیری محلی (ZIP) — بدون نیاز به Google Play Services.
 * نسخه ابری (Google Drive) در فاز طلایی از طریق Drive REST API اضافه می‌شود.
 */
@Singleton
class BackupRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    private val db: FactorYarDatabase,
) : ir.factoryar.core.domain.repository.BackupRepository {

    override suspend fun exportLocalBackup(targetUriString: String): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val uri = Uri.parse(targetUriString)
            // فایل دیتابیس را flush کن
            db.query("PRAGMA wal_checkpoint(FULL)", emptyArray()).close()

            val resolver = context.contentResolver
            resolver.openOutputStream(uri)?.use { raw ->
                ZipOutputStream(raw.buffered()).use { zip ->
                    // ۱) دیتابیس + wal/shm
                    val dbFile = context.getDatabasePath(FactorYarDatabase.DATABASE_NAME)
                    listOf(dbFile, File(dbFile.path + "-wal"), File(dbFile.path + "-shm")).forEach { f ->
                        if (f.exists()) {
                            zip.putNextEntry(ZipEntry("db/${f.name}"))
                            f.inputStream().use { it.copyTo(zip) }
                            zip.closeEntry()
                        }
                    }
                    // ۲) فایل‌ها (لوگو، امضاها)
                    val filesDir = context.filesDir
                    filesDir.walkTopDown().filter { it.isFile && (it.path.contains("logo") || it.path.contains("signature")) }
                        .forEach { f ->
                            zip.putNextEntry(ZipEntry("files/${f.relativeTo(filesDir).path}"))
                            f.inputStream().use { it.copyTo(zip) }
                            zip.closeEntry()
                        }
                    // ۳) متادیتا
                    zip.putNextEntry(ZipEntry("meta.info"))
                    zip.write("version=1\ncreatedAt=${DateUtils.now()}\n".toByteArray())
                    zip.closeEntry()
                }
            } ?: error("عدم دسترسی به مسیر خروجی")
            targetUriString
        }
    }

    override suspend fun importLocalBackup(sourceUriString: String): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            val uri = Uri.parse(sourceUriString)
            val resolver = context.contentResolver
            db.close()
            val dbFile = context.getDatabasePath(FactorYarDatabase.DATABASE_NAME)
            resolver.openInputStream(uri)?.use { raw ->
                ZipInputStream(raw.buffered()).use { zip ->
                    var entry = zip.nextEntry
                    while (entry != null) {
                        val outFile = when {
                            entry.name.startsWith("db/") ->
                                File(dbFile.parentFile, entry.name.removePrefix("db/"))
                            entry.name.startsWith("files/") ->
                                File(context.filesDir, entry.name.removePrefix("files/"))
                            else -> null
                        }
                        if (outFile != null) {
                            outFile.parentFile?.mkdirs()
                            outFile.outputStream().use { zip.copyTo(it) }
                        }
                        zip.closeEntry()
                        entry = zip.nextEntry
                    }
                }
            } ?: error("فایل پشتیبان خوانده نشد")
            Unit
        }
    }
}
