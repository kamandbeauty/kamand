package ir.factoryar.core.database.migration

import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

/**
 * نسخه ۱ → ۲: افزودن ماژول انبار/بارکد و ماژول هزینه‌ها.
 * داده‌های موجود کاربر حفظ می‌شود (بدون destructive migration).
 */
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        // --- دسته‌بندی کالا ---
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS `product_categories` (
                `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                `name` TEXT NOT NULL,
                `colorArgb` INTEGER NOT NULL,
                `sortOrder` INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_product_categories_name` ON `product_categories` (`name`)")

        // --- کالا ---
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS `products` (
                `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                `name` TEXT NOT NULL,
                `barcode` TEXT,
                `sku` TEXT NOT NULL,
                `categoryId` INTEGER,
                `unit` TEXT NOT NULL,
                `retailPrice` INTEGER NOT NULL,
                `wholesalePrice` INTEGER NOT NULL,
                `costPrice` INTEGER NOT NULL,
                `stockQuantity` REAL NOT NULL,
                `lowStockThreshold` REAL NOT NULL,
                `isService` INTEGER NOT NULL,
                `taxPercent` REAL NOT NULL,
                `note` TEXT NOT NULL,
                `active` INTEGER NOT NULL,
                `createdAt` INTEGER NOT NULL,
                `updatedAt` INTEGER NOT NULL,
                FOREIGN KEY(`categoryId`) REFERENCES `product_categories`(`id`) ON UPDATE NO ACTION ON DELETE SET NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_products_name` ON `products` (`name`)")
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_products_barcode` ON `products` (`barcode`)")
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_products_categoryId` ON `products` (`categoryId`)")
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_products_active` ON `products` (`active`)")

        // --- کاردکس انبار ---
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS `stock_movements` (
                `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                `productId` INTEGER NOT NULL,
                `quantityDelta` REAL NOT NULL,
                `reason` TEXT NOT NULL,
                `invoiceId` INTEGER,
                `note` TEXT NOT NULL,
                `createdAt` INTEGER NOT NULL,
                FOREIGN KEY(`productId`) REFERENCES `products`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_stock_movements_productId` ON `stock_movements` (`productId`)")
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_stock_movements_invoiceId` ON `stock_movements` (`invoiceId`)")
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_stock_movements_createdAt` ON `stock_movements` (`createdAt`)")

        // --- دسته هزینه ---
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS `expense_categories` (
                `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                `name` TEXT NOT NULL,
                `colorArgb` INTEGER NOT NULL,
                `isDefault` INTEGER NOT NULL,
                `sortOrder` INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_expense_categories_name` ON `expense_categories` (`name`)")

        // --- هزینه ---
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS `expenses` (
                `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                `title` TEXT NOT NULL,
                `amount` INTEGER NOT NULL,
                `categoryId` INTEGER,
                `date` INTEGER NOT NULL,
                `note` TEXT NOT NULL,
                `attachmentPath` TEXT,
                `createdAt` INTEGER NOT NULL,
                FOREIGN KEY(`categoryId`) REFERENCES `expense_categories`(`id`) ON UPDATE NO ACTION ON DELETE SET NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_expenses_categoryId` ON `expenses` (`categoryId`)")
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_expenses_date` ON `expenses` (`date`)")

        // --- اتصال اقلام فاکتور به کالا + بهای تمام‌شده ---
        db.execSQL("ALTER TABLE `invoice_items` ADD COLUMN `productId` INTEGER DEFAULT NULL")
        db.execSQL("ALTER TABLE `invoice_items` ADD COLUMN `costPrice` INTEGER NOT NULL DEFAULT 0")
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_invoice_items_productId` ON `invoice_items` (`productId`)")
    }
}

val ALL_MIGRATIONS: Array<Migration> = arrayOf(MIGRATION_1_2)
