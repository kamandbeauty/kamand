package ir.factoryar.core.data.mapper

import ir.factoryar.core.database.entity.ExpenseCategoryEntity
import ir.factoryar.core.database.entity.ExpenseEntity
import ir.factoryar.core.database.entity.ProductCategoryEntity
import ir.factoryar.core.database.entity.ProductEntity
import ir.factoryar.core.database.entity.StockMovementEntity
import ir.factoryar.core.domain.model.Expense
import ir.factoryar.core.domain.model.ExpenseCategory
import ir.factoryar.core.domain.model.Product
import ir.factoryar.core.domain.model.ProductCategory
import ir.factoryar.core.domain.model.StockMoveReason
import ir.factoryar.core.domain.model.StockMovement

fun ProductEntity.toDomain() = Product(
    id = id,
    name = name,
    barcode = barcode.orEmpty(),
    sku = sku,
    categoryId = categoryId,
    unit = unit,
    retailPrice = retailPrice,
    wholesalePrice = wholesalePrice,
    costPrice = costPrice,
    stockQuantity = stockQuantity,
    lowStockThreshold = lowStockThreshold,
    isService = isService,
    taxPercent = taxPercent,
    note = note,
    active = active,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun Product.toEntity() = ProductEntity(
    id = id,
    name = name.trim(),
    // بارکد خالی باید null باشد تا ایندکس یکتا نشکند
    barcode = barcode.trim().ifBlank { null },
    sku = sku.trim(),
    categoryId = categoryId,
    unit = unit,
    retailPrice = retailPrice,
    wholesalePrice = wholesalePrice,
    costPrice = costPrice,
    stockQuantity = stockQuantity,
    lowStockThreshold = lowStockThreshold,
    isService = isService,
    taxPercent = taxPercent,
    note = note,
    active = active,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun ProductCategoryEntity.toDomain() = ProductCategory(id, name, colorArgb, sortOrder)
fun ProductCategory.toEntity() = ProductCategoryEntity(id, name.trim(), colorArgb, sortOrder)

fun StockMovementEntity.toDomain() = StockMovement(
    id = id,
    productId = productId,
    quantityDelta = quantityDelta,
    reason = StockMoveReason.fromName(reason),
    invoiceId = invoiceId,
    note = note,
    createdAt = createdAt,
)

fun StockMovement.toEntity() = StockMovementEntity(
    id = id,
    productId = productId,
    quantityDelta = quantityDelta,
    reason = reason.name,
    invoiceId = invoiceId,
    note = note,
    createdAt = createdAt,
)

fun ExpenseEntity.toDomain() = Expense(
    id = id,
    title = title,
    amount = amount,
    categoryId = categoryId,
    date = date,
    note = note,
    attachmentPath = attachmentPath,
    createdAt = createdAt,
)

fun Expense.toEntity() = ExpenseEntity(
    id = id,
    title = title.trim(),
    amount = amount,
    categoryId = categoryId,
    date = date,
    note = note,
    attachmentPath = attachmentPath,
    createdAt = createdAt,
)

fun ExpenseCategoryEntity.toDomain() = ExpenseCategory(id, name, colorArgb, isDefault, sortOrder)
fun ExpenseCategory.toEntity() = ExpenseCategoryEntity(id, name.trim(), colorArgb, isDefault, sortOrder)
