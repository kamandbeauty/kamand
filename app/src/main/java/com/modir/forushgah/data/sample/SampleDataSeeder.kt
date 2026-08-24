package com.modir.forushgah.data.sample

import com.modir.forushgah.BuildConfig
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.data.local.dao.ProductDao
import com.modir.forushgah.data.repository.CategoryRepository
import com.modir.forushgah.data.repository.CustomerRepository
import com.modir.forushgah.data.repository.InventoryRepository
import com.modir.forushgah.data.repository.ProductRepository
import com.modir.forushgah.data.repository.SupplierRepository
import com.modir.forushgah.domain.model.Customer
import com.modir.forushgah.domain.model.InventoryMovementType
import com.modir.forushgah.domain.model.InventoryReferenceType
import com.modir.forushgah.domain.model.Product
import com.modir.forushgah.domain.model.Supplier
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Debug-only sample data (spec §17). NEVER seeds release builds and never
 * re-seeds a database that already contains products — so production data is
 * never polluted. Gives the Phase 2 screens something realistic to show on a
 * fresh debug install (products incl. low-stock and out-of-stock cases,
 * customers, suppliers, and a short inventory history).
 */
@Singleton
class SampleDataSeeder @Inject constructor(
    private val productDao: ProductDao,
    private val categoryRepository: CategoryRepository,
    private val supplierRepository: SupplierRepository,
    private val customerRepository: CustomerRepository,
    private val productRepository: ProductRepository,
    private val inventoryRepository: InventoryRepository,
) {

    suspend fun seedIfEmpty() {
        if (!BuildConfig.DEBUG) return
        if (productDao.observeActiveProductCount().first() > 0) return

        val now = System.currentTimeMillis()

        // Suppliers
        val supplierA = supplierRepository.create(
            Supplier(
                name = "شرکت پخش آریا",
                phone = "02188776655",
                address = "تهران، خیابان ولیعصر",
                notes = "تأمین‌کننده اصلی محصولات مراقبت مو",
                createdAt = now,
                updatedAt = now,
            ),
        )
        val supplierB = supplierRepository.create(
            Supplier(
                name = "گروه بازرگانی مهر",
                phone = "02166445566",
                address = "تهران، بازار مرکزی",
                createdAt = now,
                updatedAt = now,
            ),
        )

        // Categories
        val categoryHair = categoryRepository.create("مراقبت مو")
        val categorySkincare = categoryRepository.create("مراقبت پوست")
        val categoryTools = categoryRepository.create("لوازم جانبی")

        // Customers
        customerRepository.create(
            Customer(name = "سارا محمدی", mobile = "09123456789", city = "تهران", address = "تهران، ونک", createdAt = now, updatedAt = now),
        )
        customerRepository.create(
            Customer(name = "علی رضایی", mobile = "09351112233", city = "کرج", createdAt = now, updatedAt = now),
        )
        customerRepository.create(
            Customer(name = "مینا کریمی", mobile = "09199887766", city = "اصفهان", notes = "سفارش‌های مکرر", createdAt = now, updatedAt = now),
        )

        // Products — initial stock is set at creation (per spec §3 this is NOT
        // a movement: there was no prior stock to move from).
        val shampoo = productRepository.create(
            Product(
                name = "شامپو موی خشک ۴۰۰cc",
                sku = "SH-001",
                barcode = "6261001234567",
                categoryId = categoryHair,
                purchasePrice = Money(90_000),
                sellingPrice = Money(150_000),
                stockQuantity = 18,
                minimumStock = 5,
                supplierId = supplierA,
                packagingCost = Money(5_000),
                createdAt = now,
                updatedAt = now,
            ),
        )
        val conditioner = productRepository.create(
            Product(
                name = "کراتین موی چرب ۳۵cc",
                sku = "SH-002",
                categoryId = categoryHair,
                purchasePrice = Money(70_000),
                sellingPrice = Money(120_000),
                stockQuantity = 3,
                minimumStock = 5,
                supplierId = supplierA,
                packagingCost = Money(3_000),
                createdAt = now,
                updatedAt = now,
            ),
        )
        productRepository.create(
            Product(
                name = "سرم صورت ویتامین C",
                sku = "SK-101",
                categoryId = categorySkincare,
                purchasePrice = Money(180_000),
                sellingPrice = Money(320_000),
                stockQuantity = 12,
                minimumStock = 3,
                supplierId = supplierB,
                packagingCost = Money(8_000),
                createdAt = now,
                updatedAt = now,
            ),
        )
        productRepository.create(
            Product(
                name = "شانه چوبی",
                sku = "TL-201",
                categoryId = categoryTools,
                purchasePrice = Money(15_000),
                sellingPrice = Money(45_000),
                stockQuantity = 0,
                minimumStock = 4,
                supplierId = supplierB,
                packagingCost = Money.ZERO,
                createdAt = now,
                updatedAt = now,
            ),
        )

        // Inventory history — every post-creation change goes through the
        // legitimate movement path (spec §3).
        inventoryRepository.applyMovement(
            productId = shampoo,
            quantityDelta = 3,
            movementType = InventoryMovementType.PURCHASE,
            referenceType = InventoryReferenceType.MANUAL,
            note = "خرید از شرکت پخش آریا (نمونه دیباگ)",
            now = now + 60_000,
        )
        inventoryRepository.applyMovement(
            productId = shampoo,
            quantityDelta = -1,
            movementType = InventoryMovementType.SALE,
            referenceType = InventoryReferenceType.ORDER,
            referenceId = 1,
            note = "سفارش نمونه (نمونه دیباگ)",
            now = now + 120_000,
        )
        inventoryRepository.applyMovement(
            productId = conditioner,
            quantityDelta = -2,
            movementType = InventoryMovementType.ADJUSTMENT_OUT,
            referenceType = InventoryReferenceType.STOCK_ADJUSTMENT,
            note = "تلفات انبار (نمونه دیباگ)",
            now = now + 180_000,
        )
    }
}
