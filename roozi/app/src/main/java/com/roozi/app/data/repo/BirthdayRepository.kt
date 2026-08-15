package com.roozi.app.data.repo

import android.content.Context
import androidx.compose.runtime.Immutable
import com.roozi.app.core.date.BirthdayMath
import com.roozi.app.data.local.BirthdayPersonEntity
import com.roozi.app.data.local.GiftIdeaEntity
import com.roozi.app.data.local.RooziDatabase
import com.roozi.app.notifications.BirthdayScheduler
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.time.LocalDate

/** UI-facing person, with the countdown and age already resolved. */
@Immutable
data class BirthdayPerson(
    val id: Long,
    val name: String,
    val birthMonth: Int,
    val birthDay: Int,
    val birthYear: Int?,
    val relationship: String,
    val avatar: String,
    val notes: String,
    val reminderEnabled: Boolean,
    val reminderOffset: Int,
    val favoriteMessageId: Int,
    /** Days until the next birthday; 0 = today. */
    val daysUntil: Int,
    /** Age they turn on that birthday, or null when the year is unknown. */
    val turningAge: Int?,
    /** Completed years as of today, or null when unknown. */
    val currentAge: Int?
) {
    val isToday: Boolean get() = daysUntil == 0
    val isTomorrow: Boolean get() = daysUntil == 1
    val displayAvatar: String get() = avatar.ifBlank { DEFAULT_AVATAR }

    companion object {
        const val DEFAULT_AVATAR = "🎂"
    }
}

@Immutable
data class GiftIdea(
    val id: Long,
    val personId: Long,
    val title: String,
    val isCompleted: Boolean
)

/** Avatars offered when adding someone. */
object BirthdayAvatars {
    val all = listOf("🎂", "👩", "👨", "👧", "👦", "❤️", "🎁", "🌸", "🌟", "🐣", "🍰", "🎈")
}

/** Reminder lead times, in days before the birthday. */
object ReminderOffsets {
    val all = listOf(0, 1, 3, 7, 14)
}

/**
 * Birthdays, gift ideas and their reminders.
 *
 * The countdown is computed on read rather than stored, so it is always correct
 * without a nightly job: a persisted "days remaining" would silently go stale.
 */
class BirthdayRepository(
    private val context: Context,
    db: RooziDatabase = RooziDatabase.get(context),
    private val scheduler: BirthdayScheduler = BirthdayScheduler(context)
) {
    private val birthdayDao = db.birthdayDao()
    private val giftDao = db.giftIdeaDao()

    /** Everyone, sorted by how soon their birthday is. */
    val people: Flow<List<BirthdayPerson>> = birthdayDao.observeAll().map { rows ->
        val today = LocalDate.now()
        rows.map { it.toDomain(today) }.sortedBy { it.daysUntil }
    }

    fun person(id: Long): Flow<BirthdayPerson?> =
        birthdayDao.observePerson(id).map { it?.toDomain(LocalDate.now()) }

    fun giftIdeas(personId: Long): Flow<List<GiftIdea>> =
        giftDao.observeForPerson(personId).map { list ->
            list.map { GiftIdea(it.id, it.personId, it.title, it.isCompleted) }
        }

    suspend fun savePerson(
        id: Long = 0,
        name: String,
        birthMonth: Int,
        birthDay: Int,
        birthYear: Int?,
        relationship: String,
        avatar: String,
        notes: String,
        reminderEnabled: Boolean,
        reminderOffset: Int,
        favoriteMessageId: Int = 0
    ): Long {
        val existing = if (id != 0L) birthdayDao.findById(id) else null
        val now = System.currentTimeMillis()
        val entity = BirthdayPersonEntity(
            id = id,
            name = name.trim(),
            birthMonth = birthMonth.coerceIn(1, 12),
            birthDay = birthDay.coerceIn(1, 31),
            birthYear = birthYear?.takeIf { it > 0 },
            relationship = relationship.trim(),
            avatar = avatar,
            notes = notes.trim(),
            reminderEnabled = reminderEnabled,
            reminderOffset = reminderOffset,
            favoriteMessageId = if (id != 0L) {
                existing?.favoriteMessageId ?: favoriteMessageId
            } else favoriteMessageId,
            createdAt = existing?.createdAt ?: now,
            updatedAt = now
        )
        val newId = if (id == 0L) birthdayDao.insert(entity) else {
            birthdayDao.update(entity); id
        }
        syncReminder(entity.copy(id = newId))
        return newId
    }

    suspend fun setFavoriteMessage(personId: Long, messageId: Int) {
        val person = birthdayDao.findById(personId) ?: return
        birthdayDao.update(
            person.copy(favoriteMessageId = messageId, updatedAt = System.currentTimeMillis())
        )
    }

    suspend fun deletePerson(personId: Long) {
        scheduler.cancel(personId)
        birthdayDao.deleteById(personId)
    }

    suspend fun addGiftIdea(personId: Long, title: String): Long =
        giftDao.insert(GiftIdeaEntity(personId = personId, title = title.trim()))

    suspend fun updateGiftIdea(idea: GiftIdea) {
        val row = giftDao.findById(idea.id) ?: return
        giftDao.update(row.copy(title = idea.title.trim(), isCompleted = idea.isCompleted))
    }

    suspend fun deleteGiftIdea(ideaId: Long) = giftDao.deleteById(ideaId)

    /**
     * Re-arms every birthday reminder. Called at startup and after a restore,
     * and also refreshes next year's alarm once this year's has fired.
     */
    suspend fun rescheduleAll() {
        birthdayDao.withReminders().forEach { syncReminder(it) }
    }

    private fun syncReminder(person: BirthdayPersonEntity) {
        if (!person.reminderEnabled) {
            scheduler.cancel(person.id)
            return
        }
        val date = BirthdayMath.reminderDate(
            month = person.birthMonth,
            day = person.birthDay,
            daysBefore = person.reminderOffset
        )
        val daysBefore = BirthdayMath.daysUntil(person.birthMonth, person.birthDay)
        scheduler.schedule(
            personId = person.id,
            name = person.name,
            date = date,
            daysBefore = person.reminderOffset,
            actualDaysUntil = daysBefore
        )
    }

    private fun BirthdayPersonEntity.toDomain(today: LocalDate) = BirthdayPerson(
        id = id,
        name = name,
        birthMonth = birthMonth,
        birthDay = birthDay,
        birthYear = birthYear,
        relationship = relationship,
        avatar = avatar,
        notes = notes,
        reminderEnabled = reminderEnabled,
        reminderOffset = reminderOffset,
        favoriteMessageId = favoriteMessageId,
        daysUntil = BirthdayMath.daysUntil(birthMonth, birthDay, today),
        turningAge = BirthdayMath.ageAtNextBirthday(birthYear, birthMonth, birthDay, today),
        currentAge = BirthdayMath.currentAge(birthYear, birthMonth, birthDay, today)
    )

    // Backup support -------------------------------------------------------

    suspend fun snapshot(): Pair<List<BirthdayPersonEntity>, List<GiftIdeaEntity>> {
        val people = birthdayDao.observeAll().first()
        val ideas = people.flatMap { giftDao.observeForPerson(it.id).first() }
        return people to ideas
    }

    suspend fun replaceAll(people: List<BirthdayPersonEntity>, ideas: List<GiftIdeaEntity>) {
        birthdayDao.clear()
        giftDao.clear()
        birthdayDao.insertAll(people)
        giftDao.insertAll(ideas)
        rescheduleAll()
    }
}
