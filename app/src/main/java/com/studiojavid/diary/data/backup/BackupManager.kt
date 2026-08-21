package com.studiojavid.diary.data.backup

import android.content.Context
import android.net.Uri
import com.studiojavid.diary.data.local.BirthdayPersonEntity
import com.studiojavid.diary.data.local.GiftIdeaEntity
import com.studiojavid.diary.data.local.DiaryEntity
import com.studiojavid.diary.data.local.NoteEntity
import com.studiojavid.diary.data.local.NotebookEntity
import com.studiojavid.diary.data.repo.BirthdayRepository
import com.studiojavid.diary.data.repo.DiaryRepository
import com.studiojavid.diary.data.repo.NoteRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

/**
 * Local JSON backup / restore.
 *
 * The payload is a plain, versioned JSON document — deliberately transport
 * agnostic so a future cloud provider only has to move these bytes around.
 *
 * Every repository that owns user data is represented here. Birthdays in
 * particular are irreplaceable: a date the user typed in once and will never
 * be reminded of again if it is lost.
 *
 * Photos are **not** in the payload. They are binary blobs that would inflate
 * a text backup by orders of magnitude; a restored page keeps its photo file
 * name, so restoring onto the same device recovers the image, and onto a new
 * one the page is intact minus the picture.
 */
class BackupManager(
    private val context: Context,
    private val repository: DiaryRepository,
    private val noteRepository: NoteRepository? = null,
    private val birthdayRepository: BirthdayRepository? = null
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
        val root = JSONObject()
        root.put("format", FORMAT)
        root.put("version", VERSION)
        root.put("exportedAt", System.currentTimeMillis())

        val pagesArray = JSONArray()
        repository.snapshot().forEach { m ->
            pagesArray.put(
                JSONObject()
                    .put("id", m.id)
                    .put("date", m.date)
                    .put("title", m.title)
                    .put("body", m.body)
                    .put("mood", m.mood)
                    .put("tags", m.tags)
                    .put("photoUri", m.photoUri)
                    .put("favorite", m.favorite)
                    .put("createdAt", m.createdAt)
                    .put("updatedAt", m.updatedAt)
            )
        }
        root.put("pages", pagesArray)

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

        birthdayRepository?.let { birthdays ->
            val (people, ideas) = birthdays.snapshot()

            val peopleArray = JSONArray()
            people.forEach { p ->
                peopleArray.put(
                    JSONObject()
                        .put("id", p.id)
                        .put("name", p.name)
                        .put("birthMonth", p.birthMonth)
                        .put("birthDay", p.birthDay)
                        .put("birthYear", p.birthYear ?: JSONObject.NULL)
                        .put("relationship", p.relationship)
                        .put("avatar", p.avatar)
                        .put("notes", p.notes)
                        .put("reminderEnabled", p.reminderEnabled)
                        .put("reminderOffset", p.reminderOffset)
                        .put("favoriteMessageId", p.favoriteMessageId)
                        .put("createdAt", p.createdAt)
                        .put("updatedAt", p.updatedAt)
                )
            }
            root.put("people", peopleArray)

            val ideaArray = JSONArray()
            ideas.forEach { g ->
                ideaArray.put(
                    JSONObject()
                        .put("id", g.id)
                        .put("personId", g.personId)
                        .put("title", g.title)
                        .put("isCompleted", g.isCompleted)
                        .put("createdAt", g.createdAt)
                )
            }
            root.put("giftIdeas", ideaArray)
        }

        return root.toString(2)
    }

    /** @return how many diary pages were restored. */
    suspend fun parseAndApply(text: String): Int {
        val root = JSONObject(text)
        require(root.optString("format") == FORMAT) { "Unsupported backup file" }

        val pages = mutableListOf<DiaryEntity>()
        val pagesArray = root.optJSONArray("pages") ?: root.optJSONArray("memories") // legacy key ?: JSONArray()
        for (i in 0 until pagesArray.length()) {
            val o = pagesArray.getJSONObject(i)
            pages += DiaryEntity(
                id = o.getLong("id"),
                date = o.getLong("date"),
                title = o.optString("title", ""),
                body = o.optString("body", ""),
                mood = o.optInt("mood", 0),
                tags = o.optString("tags", ""),
                photoUri = o.optString("photoUri", ""),
                favorite = o.optBoolean("favorite", false),
                createdAt = o.optLong("createdAt", System.currentTimeMillis()),
                updatedAt = o.optLong("updatedAt", System.currentTimeMillis())
            )
        }
        repository.replaceAll(pages)

        // A section the file does not carry is left alone rather than wiped:
        // restoring a partial backup must not delete data it says nothing about.
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

        val birthdaysRepo = birthdayRepository
        if (birthdaysRepo != null && root.has("people")) {
            val people = mutableListOf<BirthdayPersonEntity>()
            val peopleArray = root.optJSONArray("people") ?: JSONArray()
            for (i in 0 until peopleArray.length()) {
                val o = peopleArray.getJSONObject(i)
                people += BirthdayPersonEntity(
                    id = o.getLong("id"),
                    name = o.getString("name"),
                    birthMonth = o.getInt("birthMonth"),
                    birthDay = o.getInt("birthDay"),
                    birthYear = o.optNullableLong("birthYear")?.toInt(),
                    relationship = o.optString("relationship", ""),
                    avatar = o.optString("avatar", ""),
                    notes = o.optString("notes", ""),
                    reminderEnabled = o.optBoolean("reminderEnabled", false),
                    reminderOffset = o.optInt("reminderOffset", 1),
                    favoriteMessageId = o.optInt("favoriteMessageId", 0),
                    createdAt = o.optLong("createdAt", System.currentTimeMillis()),
                    updatedAt = o.optLong("updatedAt", System.currentTimeMillis())
                )
            }

            val ideas = mutableListOf<GiftIdeaEntity>()
            val ideaArray = root.optJSONArray("giftIdeas") ?: JSONArray()
            for (i in 0 until ideaArray.length()) {
                val o = ideaArray.getJSONObject(i)
                ideas += GiftIdeaEntity(
                    id = o.getLong("id"),
                    personId = o.getLong("personId"),
                    title = o.optString("title", ""),
                    isCompleted = o.optBoolean("isCompleted", false),
                    createdAt = o.optLong("createdAt", System.currentTimeMillis())
                )
            }
            birthdaysRepo.replaceAll(people, ideas)
        }

        return memories.size
    }

    private fun JSONObject.optNullableLong(key: String): Long? =
        if (isNull(key)) null else optLong(key)

    companion object {
        const val FORMAT = "diary-backup"
        const val VERSION = 1
        const val MIME = "application/json"

        fun suggestedFileName(): String {
            val stamp = java.text.SimpleDateFormat("yyyyMMdd-HHmm", java.util.Locale.US)
                .format(java.util.Date())
            return "diary-backup-$stamp.json"
        }
    }
}
