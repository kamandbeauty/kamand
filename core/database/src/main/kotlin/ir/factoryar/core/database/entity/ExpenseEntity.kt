package ir.factoryar.core.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "expense_categories",
    indices = [Index(value = ["name"], unique = true)],
)
data class ExpenseCategoryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val colorArgb: Long = 0xFF795548,
    val isDefault: Boolean = false,
    val sortOrder: Int = 0,
)

@Entity(
    tableName = "expenses",
    foreignKeys = [
        ForeignKey(
            entity = ExpenseCategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["categoryId"],
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [Index(value = ["categoryId"]), Index(value = ["date"])],
)
data class ExpenseEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val amount: Long,
    val categoryId: Long? = null,
    val date: Long,
    val note: String = "",
    val attachmentPath: String? = null,
    val createdAt: Long = 0,
)

/** جمع هزینه به تفکیک دسته */
data class ExpenseCategoryTotalRow(
    val categoryId: Long?,
    val categoryName: String?,
    val total: Long,
    val count: Int,
)
