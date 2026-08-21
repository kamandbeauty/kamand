package com.studiojavid.diary.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

/**
 * Schema starts at version 1: this app has never shipped, so there is no
 * installed database to migrate from. The task/category tables ROOZI carried
 * are absent rather than deprecated — a diary has no to-do list, and keeping
 * dead tables would mislead every future migration author.
 *
 * Every schema change from here on needs a real [androidx.room.migration.Migration];
 * the destructive fallback below is a crash guard, not a migration strategy.
 */
@Database(
    entities = [
        DiaryEntity::class,
        NoteEntity::class,
        NotebookEntity::class,
        BirthdayPersonEntity::class,
        GiftIdeaEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class DiaryDatabase : RoomDatabase() {

    abstract fun diaryDao(): DiaryDao
    abstract fun noteDao(): NoteDao
    abstract fun notebookDao(): NotebookDao
    abstract fun birthdayDao(): BirthdayDao
    abstract fun giftIdeaDao(): GiftIdeaDao

    companion object {
        @Volatile
        private var instance: DiaryDatabase? = null

        fun get(context: Context): DiaryDatabase = instance ?: synchronized(this) {
            instance ?: build(context.applicationContext).also { instance = it }
        }

        private fun build(context: Context): DiaryDatabase =
            Room.databaseBuilder(context, DiaryDatabase::class.java, "diary.db")
                // Last-resort safety net: if a database from an unknown build
                // cannot be opened, recreate it rather than throwing on open —
                // an unopenable database crashes the app on every launch with
                // no way for the user to recover.
                .fallbackToDestructiveMigration()
                .build()
    }
}
