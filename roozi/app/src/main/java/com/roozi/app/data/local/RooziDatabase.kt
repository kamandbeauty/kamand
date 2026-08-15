package com.roozi.app.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [
        TaskEntity::class,
        CategoryEntity::class,
        NoteEntity::class,
        NotebookEntity::class
    ],
    version = 3,
    exportSchema = false
)
abstract class RooziDatabase : RoomDatabase() {

    abstract fun taskDao(): TaskDao
    abstract fun categoryDao(): CategoryDao
    abstract fun noteDao(): NoteDao
    abstract fun notebookDao(): NotebookDao

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

        /**
         * v2 -> v3 introduces notes and notebooks. Purely additive: existing
         * task, category and settings rows are untouched.
         */
        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `notebooks` (
                        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                        `name` TEXT NOT NULL,
                        `icon` TEXT NOT NULL,
                        `color` INTEGER NOT NULL,
                        `builtInKey` TEXT NOT NULL DEFAULT '',
                        `createdAt` INTEGER NOT NULL
                    )
                    """.trimIndent()
                )
                db.execSQL(
                    "CREATE UNIQUE INDEX IF NOT EXISTS `index_notebooks_name` ON `notebooks` (`name`)"
                )
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `notes` (
                        `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                        `title` TEXT NOT NULL,
                        `body` TEXT NOT NULL,
                        `notebookId` INTEGER,
                        `color` INTEGER NOT NULL DEFAULT 0,
                        `pinned` INTEGER NOT NULL,
                        `createdAt` INTEGER NOT NULL,
                        `updatedAt` INTEGER NOT NULL,
                        FOREIGN KEY(`notebookId`) REFERENCES `notebooks`(`id`)
                            ON UPDATE NO ACTION ON DELETE SET NULL
                    )
                    """.trimIndent()
                )
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_notes_notebookId` ON `notes` (`notebookId`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_notes_updatedAt` ON `notes` (`updatedAt`)")
            }
        }

        fun get(context: Context): RooziDatabase = instance ?: synchronized(this) {
            instance ?: build(context.applicationContext).also { instance = it }
        }

        private fun build(context: Context): RooziDatabase =
            Room.databaseBuilder(context, RooziDatabase::class.java, "roozi.db")
                .addMigrations(MIGRATION_1_2, MIGRATION_2_3)
                // Last-resort safety net: if a database from an unknown/older
                // build cannot be migrated, recreate it instead of throwing on
                // open — an unopenable database would crash the app on every
                // launch with no way for the user to recover.
                .fallbackToDestructiveMigration()
                .build()
    }
}
