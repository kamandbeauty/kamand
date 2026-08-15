package com.roozi.app.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Priority of a task. Stored as an ordinal-independent int so reordering the
 * enum can never corrupt existing data.
 */
enum class Priority(val value: Int) {
    LOW(0), MEDIUM(1), HIGH(2);

    companion object {
        fun from(value: Int): Priority = entries.firstOrNull { it.value == value } ?: MEDIUM
    }
}

@Entity(
    tableName = "categories",
    indices = [Index(value = ["name"], unique = true)]
)
data class CategoryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    /** Emoji shown next to the category. */
    val icon: String,
    /** ARGB color packed into an Int. */
    val color: Int,
    /** Resource key for built-in categories so they can be localized. */
    @ColumnInfo(defaultValue = "") val builtInKey: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "tasks",
    foreignKeys = [
        ForeignKey(
            entity = CategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["categoryId"],
            onDelete = ForeignKey.SET_NULL
        )
    ],
    indices = [Index("categoryId"), Index("dueDate"), Index("isCompleted")]
)
data class TaskEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val description: String = "",
    val categoryId: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    /** Epoch day (UTC-independent civil date). Null = no date. */
    val dueDate: Long? = null,
    /** Minutes since midnight. Null = all-day. */
    val dueTime: Int? = null,
    val isCompleted: Boolean = false,
    val completedAt: Long? = null,
    val priority: Int = Priority.MEDIUM.value,
    val reminderEnabled: Boolean = false,
    /** Absolute epoch millis of the reminder trigger. */
    val reminderTime: Long? = null,
    /**
     * Serialized [com.roozi.app.core.recurrence.RecurrenceRule].
     * Empty string means the task does not repeat.
     */
    @ColumnInfo(defaultValue = "") val repeatRule: String = "",
    val sortOrder: Int = 0
)
