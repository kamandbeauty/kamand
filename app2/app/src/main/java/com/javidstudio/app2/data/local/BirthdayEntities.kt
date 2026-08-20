package com.javidstudio.app2.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * A person whose birthday we track.
 *
 * The date is stored as a Jalali month/day pair rather than an absolute date:
 * a birthday is an anniversary, and the Gregorian day it falls on shifts every
 * year. [birthYear] is optional — many people only remember the day.
 */
@Entity(
    tableName = "birthday_people",
    indices = [Index("birthMonth"), Index("birthDay")]
)
data class BirthdayPersonEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    /** Jalali month, 1..12 */
    val birthMonth: Int,
    /** Jalali day, 1..31 */
    val birthDay: Int,
    /** Jalali birth year, or null when unknown (age is then hidden). */
    val birthYear: Int? = null,
    /** Free-text relationship; empty when not set. */
    @ColumnInfo(defaultValue = "") val relationship: String = "",
    /** Emoji avatar; empty means use the default. */
    @ColumnInfo(defaultValue = "") val avatar: String = "",
    @ColumnInfo(defaultValue = "") val notes: String = "",
    val reminderEnabled: Boolean = false,
    /** Days before the birthday to notify: 0, 1, 3, 7 or 14. */
    @ColumnInfo(defaultValue = "1") val reminderOffset: Int = 1,
    /** Id of the greeting the user picked for this person, 0 = none. */
    @ColumnInfo(defaultValue = "0") val favoriteMessageId: Int = 0,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "gift_ideas",
    foreignKeys = [
        ForeignKey(
            entity = BirthdayPersonEntity::class,
            parentColumns = ["id"],
            childColumns = ["personId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("personId")]
)
data class GiftIdeaEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val personId: Long,
    val title: String,
    val isCompleted: Boolean = false,
    val createdAt: Long = System.currentTimeMillis()
)
