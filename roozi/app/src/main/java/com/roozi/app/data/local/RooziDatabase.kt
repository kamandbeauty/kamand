package com.roozi.app.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [TaskEntity::class, CategoryEntity::class],
    version = 2,
    exportSchema = true
)
abstract class RooziDatabase : RoomDatabase() {

    abstract fun taskDao(): TaskDao
    abstract fun categoryDao(): CategoryDao

    companion object {
        @Volatile
        private var instance: RooziDatabase? = null

        /**
         * v1 -> v2 adds the recurrence column. Existing rows keep their data and
         * default to "no repeat", so upgrading never loses a task.
         */
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE tasks ADD COLUMN repeatRule TEXT NOT NULL DEFAULT ''")
            }
        }

        fun get(context: Context): RooziDatabase = instance ?: synchronized(this) {
            instance ?: build(context.applicationContext).also { instance = it }
        }

        private fun build(context: Context): RooziDatabase =
            Room.databaseBuilder(context, RooziDatabase::class.java, "roozi.db")
                .addMigrations(MIGRATION_1_2)
                .build()
    }
}
