package com.modir.forushgah.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.modir.forushgah.data.local.entity.EmployeeCommissionRuleEntity
import com.modir.forushgah.data.local.entity.EmployeeEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface EmployeeDao {
    @Insert
    suspend fun insert(employee: EmployeeEntity): Long

    @Query("SELECT * FROM employees WHERE isActive = 1 ORDER BY name ASC")
    fun observeActive(): Flow<List<EmployeeEntity>>

    @Insert
    suspend fun insertCommissionRule(rule: EmployeeCommissionRuleEntity): Long

    @Query("SELECT * FROM employee_commission_rules WHERE employeeId = :employeeId")
    suspend fun getRulesForEmployee(employeeId: Long): List<EmployeeCommissionRuleEntity>
}
