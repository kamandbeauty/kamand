package com.studiojavid.memory.data.backup

import android.content.Context
import android.net.Uri
import com.studiojavid.memory.data.local.CategoryEntity
import com.studiojavid.memory.data.local.NoteEntity
import com.studiojavid.memory.data.local.NotebookEntity
import com.studiojavid.memory.data.local.TaskEntity
import com.studiojavid.memory.data.repo.NoteRepository
import com.studiojavid.memory.data.repo.TaskRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

/**
 * Local JSON backup / restore.
 *
 * The payload is a plain, versioned JSON document — deliberately transport
 * agnostic so a future cloud provider only has to move these bytes around.
 */
class BackupManager(
    private val context: Context,
    private val repository: TaskRepository,
    private val noteRepository: NoteRepository? = null
) {

    suspend fun export(uri: Uri): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            val json = buildJson()
            context.contentResolver.openOutputStream(uri, "wt")?.use { out ->
                out.write(json.toByteArray(Charsets.UTF_8))
            } ?: error("Cannot open output stream")
        }
    }

    suspend fun import(uri: Uri): Result<Int> = withContext(Dispatchers.IO) {
        runCatching {
            val text = context.contentResolver.openInputStream(uri)?.use {
                it.readBytes().toString(Charsets.UTF_8)
            } ?: error("Cannot open input stream")
            parseAndApply(text)
        }
    }

    suspend fun buildJson(): String {
        val (tasks, categories) = repository.snapshot()
        val root = JSONObject()
        root.put("format", FORMAT)
        root.put("version", VERSION)
        root.put("exportedAt", System.currentTimeMillis())

        val catArray = JSONArray()
        categories.forEach { c ->
            catArray.put(
                JSONObject()
                    .put("id", c.id)
                    .put("name", c.name)
                    .put("icon", c.icon)
                    .put("color", c.color)
                    .put("builtInKey", c.builtInKey)
                    .put("createdAt", c.createdAt)
            )
        }
        root.put("categories", catArray)

        val taskArray = JSONArray()
        tasks.forEach { t ->
            taskArray.put(
                JSONObject()
                    .put("id", t.id)
                    .put("title", t.title)
                    .put("description", t.description)
                    .put("categoryId", t.categoryId ?: JSONObject.NULL)
                    .put("createdAt", t.createdAt)
                    .put("dueDate", t.dueDate ?: JSONObject.NULL)
                    .put("dueTime", t.dueTime ?: JSONObject.NULL)
                    .put("isCompleted", t.isCompleted)
                    .put("completedAt", t.completedAt ?: JSONObject.NULL)
                    .put("priority", t.priority)
                    .put("reminderEnabled", t.reminderEnabled)
                    .put("reminderTime", t.reminderTime ?: JSONObject.NULL)
                    .put("repeatRule", t.repeatRule)
                    .put("sortOrder", t.sortOrder)
            )
        }
        root.put("tasks", taskArray)

        // Notes are part of the user's data too; omitting them would make a
        // "backup" quietly lossy.
        noteRepository?.let { notes ->
            val (noteRows, notebookRows) = notes.snapshot()

            val notebookArray = JSONArray()
            notebookRows.forEach { b ->
                notebookArray.put(
                    JSONObject()
                        .put("id", b.id)
                        .put("name", b.name)
                        .put("icon", b.icon)
                        .put("color", b.color)
                        .put("builtInKey", b.builtInKey)
                        .put("createdAt", b.createdAt)
                )
            }
            root.put("notebooks", notebookArray)

            val noteArray = JSONArray()
            noteRows.forEach { n ->
                noteArray.put(
                    JSONObject()
                        .put("id", n.id)
                        .put("title", n.title)
                        .put("body", n.body)
                        .put("notebookId", n.notebookId ?: JSONObject.NULL)
                        .put("color", n.color)
                        .put("pinned", n.pinned)
                        .put("createdAt", n.createdAt)
                        .put("updatedAt", n.updatedAt)
                )
            }
            root.put("notes", noteArray)
        }

        return root.toString(2)
    }

    suspend fun parseAndApply(text: String): Int {
        val root = JSONObject(text)
        require(root.optString("format") == FORMAT) { "Unsupported backup file" }

        val categories = mutableListOf<CategoryEntity>()
        val catArray = root.optJSONArray("categories") ?: JSONArray()
        for (i in 0 until catArray.length()) {
            val o = catArray.getJSONObject(i)
            categories += CategoryEntity(
                id = o.getLong("id"),
                name = o.getString("name"),
                icon = o.optString("icon", "✨"),
                color = o.optInt("color", 0xFF7C5CFF.toInt()),
                builtInKey = o.optString("builtInKey", ""),
                createdAt = o.optLong("createdAt", System.currentTimeMillis())
            )
        }

        val tasks = mutableListOf<TaskEntity>()
        val taskArray = root.optJSONArray("tasks") ?: JSONArray()
        for (i in 0 until taskArray.length()) {
            val o = taskArray.getJSONObject(i)
            tasks += TaskEntity(
                id = o.getLong("id"),
                title = o.getString("title"),
                description = o.optString("description", ""),
                categoryId = o.optNullableLong("categoryId"),
                createdAt = o.optLong("createdAt", System.currentTimeMillis()),
                dueDate = o.optNullableLong("dueDate"),
                dueTime = o.optNullableLong("dueTime")?.toInt(),
                isCompleted = o.optBoolean("isCompleted", false),
                completedAt = o.optNullableLong("completedAt"),
                priority = o.optInt("priority", 1),
                reminderEnabled = o.optBoolean("reminderEnabled", false),
                reminderTime = o.optNullableLong("reminderTime"),
                repeatRule = o.optString("repeatRule", ""),
                sortOrder = o.optInt("sortOrder", 0)
            )
        }

        repository.replaceAll(tasks, categories)

        // Older backups have no notes section; leave existing notes untouched.
        val notesRepo = noteRepository
        if (notesRepo != null && root.has("notes")) {
            val notebooks = mutableListOf<NotebookEntity>()
            val notebookArray = root.optJSONArray("notebooks") ?: JSONArray()
            for (i in 0 until notebookArray.length()) {
                val o = notebookArray.getJSONObject(i)
                notebooks += NotebookEntity(
                    id = o.getLong("id"),
                    name = o.getString("name"),
                    icon = o.optString("icon", "📔"),
                    color = o.optInt("color", 0xFF7C5CFF.toInt()),
                    builtInKey = o.optString("builtInKey", ""),
                    createdAt = o.optLong("createdAt", System.currentTimeMillis())
                )
            }

            val notes = mutableListOf<NoteEntity>()
            val noteArray = root.optJSONArray("notes") ?: JSONArray()
            for (i in 0 until noteArray.length()) {
                val o = noteArray.getJSONObject(i)
                notes += NoteEntity(
                    id = o.getLong("id"),
                    title = o.optString("title", ""),
                    body = o.optString("body", ""),
                    notebookId = o.optNullableLong("notebookId"),
                    color = o.optInt("color", 0),
                    pinned = o.optBoolean("pinned", false),
                    createdAt = o.optLong("createdAt", System.currentTimeMillis()),
                    updatedAt = o.optLong("updatedAt", System.currentTimeMillis())
                )
            }
            notesRepo.replaceAll(notes, notebooks)
        }

        return tasks.size
    }

    private fun JSONObject.optNullableLong(key: String): Long? =
        if (isNull(key)) null else optLong(key)

    companion object {
        const val FORMAT = "memory-backup"
        const val VERSION = 3
        const val MIME = "application/json"

        fun suggestedFileName(): String {
            val stamp = java.text.SimpleDateFormat("yyyyMMdd-HHmm", java.util.Locale.US)
                .format(java.util.Date())
            return "memory-backup-$stamp.json"
        }
    }
}
