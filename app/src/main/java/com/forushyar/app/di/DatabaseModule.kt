package com.forushyar.app.di

import android.content.Context
import androidx.room.Room
import com.forushyar.app.data.local.AppDatabase
import com.forushyar.app.data.local.dao.CustomerDao
import com.forushyar.app.data.local.dao.OrderDao
import com.forushyar.app.data.local.dao.OrderItemDao
import com.forushyar.app.data.local.dao.ProductDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, DATABASE_NAME).build()

    @Provides
    fun provideCustomerDao(db: AppDatabase): CustomerDao = db.customerDao()

    @Provides
    fun provideProductDao(db: AppDatabase): ProductDao = db.productDao()

    @Provides
    fun provideOrderDao(db: AppDatabase): OrderDao = db.orderDao()

    @Provides
    fun provideOrderItemDao(db: AppDatabase): OrderItemDao = db.orderItemDao()

    private const val DATABASE_NAME = "forushyar.db"
}
