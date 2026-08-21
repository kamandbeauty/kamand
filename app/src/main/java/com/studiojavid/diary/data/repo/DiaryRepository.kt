package com.studiojavid.diary.data.repo

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Immutable
import com.studiojavid.diary.core.date.JalaliDate
import com.studiojavid.diary.data.local.DayMark
import com.studiojavid.diary.data.local.DiaryDatabase
import com.studiojavid.diary.data.local.DiaryEntity
import com.studiojavid.diary.data.local.Mood
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.io.File
import java.time.LocalDate
import java.util.UUID

/** UI-facing diary page with resolved date and mood types. */
@Immutable
data class DiaryPage(
    val id: Long,
    val date: LocalDate,
    val title: String,
    val body: String,
    val mood: Mood,
    val tags: List<String>,
    /** File name inside the private photo directory; empty when none. */
    val photo: String,
    val favorite: Boolean,
    val createdAt: Long,
    val updatedAt: Long
) {
    val hasPhoto: Boolean get() = photo.isNotEmpty()
    val isEmpty: Boolean get() = title.isBlank() && body.isBlank() && !hasPhoto
}

/**
 * Single source of truth for diary pages.
 *
 * A page is keyed by its civil date, so saving is an upsert on the date rather
 * than on the row id: opening today twice must edit one page, never create a
 * second. The repository also owns the photo files, because an orphaned image
 * left behind by a deleted page would silently grow the app's storage forever.
 */
class DiaryRepository(
    private val context: Context,
    db: DiaryDatabase = DiaryDatabase.get(context)
) {
    private val dao = db.diaryDao()

    val allPages: Flow<List<DiaryPage>> = dao.observeAll().map { it.toDomain() }

    val favorites: Flow<List<DiaryPage>> = dao.observeFavorites().map { it.toDomain() }

    val pageCount: Flow<Int> = dao.observeCount()

    /** Distinct days that have a page, newest first — the writing streak input. */
    val writtenDays: Flow<List<LocalDate>> =
        dao.observeWrittenDays().map { days -> days.map(LocalDate::ofEpochDay) }

    fun pageOn(date: LocalDate): Flow<DiaryPage?> =
        dao.observeByDate(date.toEpochDay()).map { it?.toDomain() }

    fun pagesBetween(from: LocalDate, to: LocalDate): Flow<List<DiaryPage>> =
        dao.observeBetween(from.toEpochDay(), to.toEpochDay()).map { it.toDomain() }

    fun dayMarks(from: LocalDate, to: LocalDate): Flow<List<DayMark>> =
        dao.observeDayMarks(from.toEpochDay(), to.toEpochDay())

    /**
     * "On this day" — the same Jalali day and month in previous years.
     *
     * The Jalali month/day of a date cannot be expressed in SQL, so the
     * matching Gregorian days are computed here with the calendar engine and
     * queried by exact date. Years with no such day (31 Esfand in a common
     * year) simply produce no candidate.
     */
    fun onThisDay(today: LocalDate = LocalDate.now(), yearsBack: Int = 10): Flow<List<DiaryPage>> {
        val anniversary = JalaliDate.fromLocalDate(today)
        val candidates = (1..yearsBack).mapNotNull { back ->
            val year = anniversary.year - back
            // 30 Esfand only exists in a leap year; skip the years without it
            // rather than silently sliding the anniversary onto the 29th.
            if (anniversary.day <= JalaliDate.monthLength(year, anniversary.month)) {
                JalaliDate(year, anniversary.month, anniversary.day).toEpochDay()
            } else {
                null
            }
        }
        if (candidates.isEmpty()) return dao.observeOnDays(emptyList()).map { emptyList() }
        return dao.observeOnDays(candidates).map { it.toDomain() }
    }

    // ------------------------------------------------------------------
    // Writes
    // ------------------------------------------------------------------

    /**
     * Creates or updates the page of [date].
     *
     * A page that ends up with no title, no body and no photo is deleted
     * instead of stored: an empty page would still put a dot on the calendar
     * and claim a day of the streak the user did not actually write.
     */
    suspend fun savePage(
        date: LocalDate,
        title: String,
        body: String,
        mood: Mood,
        tags: List<String>,
        photo: String,
        favorite: Boolean
    ): Long {
        val existing = dao.findByDate(date.toEpochDay())
        val cleanTitle = title.trim()
        val cleanBody = body.trim()

        if (cleanTitle.isEmpty() && cleanBody.isEmpty() && photo.isEmpty()) {
            existing?.let { deletePage(it.id) }
            return 0
        }

        val now = System.currentTimeMillis()
        // The photo file is replaced, so the previous one is now unreachable.
        if (existing != null && existing.photoUri.isNotEmpty() && existing.photoUri != photo) {
            deletePhotoFile(existing.photoUri)
        }
        val entity = DiaryEntity(
            id = existing?.id ?: 0,
            date = date.toEpochDay(),
            title = cleanTitle,
            body = cleanBody,
            mood = mood.value,
            tags = tags.filter { it.isNotBlank() }.joinToString(","),
            photoUri = photo,
            favorite = favorite,
            createdAt = existing?.createdAt ?: now,
            updatedAt = now
        )
        return if (existing == null) dao.insert(entity) else {
            dao.update(entity); existing.id
        }
    }

    suspend fun setFavorite(id: Long, favorite: Boolean) {
        val page = dao.findById(id) ?: return
        dao.update(page.copy(favorite = favorite, updatedAt = System.currentTimeMillis()))
    }

    suspend fun deletePage(id: Long) {
        val page = dao.findById(id) ?: return
        if (page.photoUri.isNotEmpty()) deletePhotoFile(page.photoUri)
        dao.deleteById(id)
    }

    /** Restores a deleted page (undo), keeping its original id and photo. */
    suspend fun restorePage(page: DiaryPage) {
        dao.insert(
            DiaryEntity(
                id = page.id,
                date = page.date.toEpochDay(),
                title = page.title,
                body = page.body,
                mood = page.mood.value,
                tags = page.tags.joinToString(","),
                photoUri = page.photo,
                favorite = page.favorite,
                createdAt = page.createdAt,
                updatedAt = page.updatedAt
            )
        )
    }

    // ------------------------------------------------------------------
    // Photos
    // ------------------------------------------------------------------

    private val photoDir: File
        get() = File(context.filesDir, PHOTO_DIR).apply { if (!exists()) mkdirs() }

    fun photoFile(name: String): File? =
        name.takeIf { it.isNotEmpty() }?.let { File(photoDir, it) }?.takeIf { it.exists() }

    /**
     * Copies a picked image into app-private storage and returns its file name.
     *
     * The gallery Uri itself is not stored: the read grant it carries is scoped
     * to this process and dies with it, so a saved page would show a broken
     * image after the next launch.
     */
    suspend fun importPhoto(source: Uri): String? = withContext(Dispatchers.IO) {
        runCatching {
            val name = "${UUID.randomUUID()}.jpg"
            val target = File(photoDir, name)
            context.contentResolver.openInputStream(source)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: error("Cannot open the picked image")
            name
        }.getOrNull()
    }

    private fun deletePhotoFile(name: String) {
        runCatching { File(photoDir, name).delete() }
    }

    /**
     * Removes photo files no page references any more. Restore replaces the
     * whole table, which can strand files that belonged to the previous data.
     */
    private suspend fun pruneOrphanPhotos() {
        val referenced = dao.observeAll().first().map { it.photoUri }.filter { it.isNotEmpty() }.toSet()
        photoDir.listFiles()?.forEach { file ->
            if (file.name !in referenced) file.delete()
        }
    }

    // ------------------------------------------------------------------
    // Backup support
    // ------------------------------------------------------------------

    suspend fun snapshot(): List<DiaryEntity> = dao.observeAll().first()

    suspend fun replaceAll(pages: List<DiaryEntity>) {
        dao.clear()
        dao.insertAll(pages)
        pruneOrphanPhotos()
    }

    private companion object {
        const val PHOTO_DIR = "diary_photos"
    }
}

private fun List<DiaryEntity>.toDomain(): List<DiaryPage> = map { it.toDomain() }

private fun DiaryEntity.toDomain() = DiaryPage(
    id = id,
    date = LocalDate.ofEpochDay(date),
    title = title,
    body = body,
    mood = Mood.from(mood),
    tags = if (tags.isEmpty()) emptyList() else tags.split(",").filter { it.isNotBlank() },
    photo = photoUri,
    favorite = favorite,
    createdAt = createdAt,
    updatedAt = updatedAt
)
