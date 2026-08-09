package ir.factoryar.core.domain

import ir.factoryar.core.domain.model.Product
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProductStockTest {

    private fun product(
        stock: Double = 10.0,
        threshold: Double = 3.0,
        service: Boolean = false,
        cost: Long = 50_000,
        retail: Long = 80_000,
        wholesale: Long = 70_000,
    ) = Product(
        id = 1,
        name = "کالای نمونه",
        retailPrice = retail,
        wholesalePrice = wholesale,
        costPrice = cost,
        stockQuantity = stock,
        lowStockThreshold = threshold,
        isService = service,
    )

    @Test
    fun `هشدار کمبود موجودی وقتی به حد آستانه رسید فعال می شود`() {
        assertFalse(product(stock = 10.0, threshold = 3.0).isLowStock)
        assertTrue(product(stock = 3.0, threshold = 3.0).isLowStock)
        assertTrue(product(stock = 1.0, threshold = 3.0).isLowStock)
    }

    @Test
    fun `آستانه صفر یعنی هشدار غیرفعال`() {
        assertFalse(product(stock = 0.0, threshold = 0.0).isLowStock)
    }

    @Test
    fun `خدمات هیچ وقت کمبود موجودی ندارند`() {
        val service = product(stock = 0.0, threshold = 5.0, service = true)
        assertFalse(service.isLowStock)
        assertFalse(service.isOutOfStock)
        assertEquals(0, service.stockValue)
    }

    @Test
    fun `ناموجود بودن با موجودی صفر یا منفی تشخیص داده می شود`() {
        assertTrue(product(stock = 0.0).isOutOfStock)
        assertTrue(product(stock = -2.0).isOutOfStock)
        assertFalse(product(stock = 0.5).isOutOfStock)
    }

    @Test
    fun `ارزش انبار بر مبنای بهای تمام شده است`() {
        assertEquals(500_000, product(stock = 10.0, cost = 50_000).stockValue)
    }

    @Test
    fun `قیمت عمده در صورت تعریف اعمال می شود`() {
        val p = product(retail = 80_000, wholesale = 70_000)
        assertEquals(80_000, p.priceFor(wholesale = false))
        assertEquals(70_000, p.priceFor(wholesale = true))
    }

    @Test
    fun `اگر قیمت عمده صفر باشد قیمت خرده استفاده می شود`() {
        val p = product(retail = 80_000, wholesale = 0)
        assertEquals(80_000, p.priceFor(wholesale = true))
    }
}
