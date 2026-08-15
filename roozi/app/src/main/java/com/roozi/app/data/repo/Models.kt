package com.roozi.app.data.repo

import androidx.compose.runtime.Immutable
import com.roozi.app.data.local.CategoryEntity
import com.roozi.app.data.local.Priority
import com.roozi.app.data.local.TaskEntity
import java.time.LocalDate

/** UI-facing category model. Built-in categories resolve their label from resources. */
@Immutable
data class Category(
    val id: Long,
    val rawName: String,
    val icon: String,
    val color: Int,
    val builtInKey: String
) {
    val isBuiltIn: Boolean get() = builtInKey.isNotEmpty()
}

/** UI-facing task model with resolved date types. */
@Immutable
data class Task(
    val id: Long,
    val title: String,
    val description: String,
    val category: Category?,
    val createdAt: Long,
    val dueDate: LocalDate?,
    val dueTimeMinutes: Int?,
    val isCompleted: Boolean,
    val completedAt: Long?,
    val priority: Priority,
    val reminderEnabled: Boolean,
    val reminderTime: Long?,
    val sortOrder: Int
) {
    val hasTime: Boolean get() = dueTimeMinutes != null
}

fun TaskEntity.toDomain(categories: Map<Long, Category>): Task = Task(
    id = id,
    title = title,
    description = description,
    category = categoryId?.let { categories[it] },
    createdAt = createdAt,
    dueDate = dueDate?.let { LocalDate.ofEpochDay(it) },
    dueTimeMinutes = dueTime,
    isCompleted = isCompleted,
    completedAt = completedAt,
    priority = Priority.from(priority),
    reminderEnabled = reminderEnabled,
    reminderTime = reminderTime,
    sortOrder = sortOrder
)

fun Task.toEntity(): TaskEntity = TaskEntity(
    id = id,
    title = title,
    description = description,
    categoryId = category?.id,
    createdAt = createdAt,
    dueDate = dueDate?.toEpochDay(),
    dueTime = dueTimeMinutes,
    isCompleted = isCompleted,
    completedAt = completedAt,
    priority = priority.value,
    reminderEnabled = reminderEnabled,
    reminderTime = reminderTime,
    sortOrder = sortOrder
)

fun CategoryEntity.toDomain(): Category = Category(id, name, icon, color, builtInKey)
