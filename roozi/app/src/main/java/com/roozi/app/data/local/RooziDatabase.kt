package com.roozi.app.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [TaskEntity::class, CategoryEntity::class],
    version = 1,
    exportSchema = true
)
abstract class RooziDatabase : RoomDatabase() {

    abstract fun taskDao(): TaskDao
    abstract fun categoryDao(): CategoryDao

    companion object {
        @Volatile
        private var instance: RooziDatabase? = null

        fun get(context: Context): RooziDatabase = instance ?: synchronized(this) {
            instance ?: build(context.applicationContext).also { instance = it }
        }

        private fun build(context: Context): RooziDatabase =
            Room.databaseBuilder(context, RooziDatabase::class.java, "roozi.db")
                .build()
    }
}
