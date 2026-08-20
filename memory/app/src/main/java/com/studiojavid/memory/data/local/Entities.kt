package com.studiojavid.memory.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * How the day felt. Stored as a stable int rather than an ordinal so the enum
 * can be reordered or extended without rewriting existing rows.
 */
enum class Mood(val value: Int) {
    UNSET(0), AWFUL(1), BAD(2), OKAY(3), GOOD(4), GREAT(5);

    companion object {
        fun from(value: Int): Mood = entries.firstOrNull { it.value == value } ?: UNSET
    }
}

/**
 * One diary page.
 *
 * [date] is an epoch day and is **unique**: this is a dated journal, one page
 * per day, so re-opening a day edits the existing page instead of stacking a
 * second one. Storing the civil date rather than a timestamp keeps the page
 * attached to the day it describes even if the user travels across time zones.
 *
 * [photoUri] holds a single image copied into app-private storage. A copy is
 * necessary because a gallery `content://` permission does not survive a reboot
 * or the user deleting the original.
 */
@Entity(
    tableName = "memories",
    indices = [Index(value = ["date"], unique = true), Index("mood")]
)
data class MemoryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    /** Epoch day of the page. */
    val date: Long,
    val title: String = "",
    val body: String = "",
    val mood: Int = Mood.UNSET.value,
    /** Emoji tags, comma separated; empty when none. */
    @ColumnInfo(defaultValue = "") val tags: String = "",
    /** File name inside the app-private photos directory; empty when none. */
    @ColumnInfo(defaultValue = "") val photoUri: String = "",
    val favorite: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)
