package com.modir.forushgah.data.local.converter

import androidx.room.TypeConverter
import com.modir.forushgah.core.common.Money

/**
 * All Money values are persisted as plain Long (Toman) columns — never as
 * Double/Float — per the project's decimal-safety rule.
 */
class MoneyConverters {
    @TypeConverter
    fun fromMoney(money: Money): Long = money.amountInToman

    @TypeConverter
    fun toMoney(value: Long): Money = Money(value)
}
