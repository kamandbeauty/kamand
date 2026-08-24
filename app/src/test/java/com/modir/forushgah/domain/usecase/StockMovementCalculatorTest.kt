package com.modir.forushgah.domain.usecase

import com.google.common.truth.Truth.assertThat
import com.modir.forushgah.domain.model.InsufficientStockException
import com.modir.forushgah.domain.usecase.inventory.StockMovementCalculator
import org.junit.Assert.assertThrows
import org.junit.Test

class StockMovementCalculatorTest {

    @Test
    fun `purchase increases stock`() {
        // Initial 10, purchase +20 -> 30
        val result = StockMovementCalculator.applyDelta(productId = 1, currentStock = 10, delta = 20)
        assertThat(result.stockBefore).isEqualTo(10)
        assertThat(result.stockAfter).isEqualTo(30)
    }

    @Test
    fun `sale decreases stock`() {
        val result = StockMovementCalculator.applyDelta(productId = 1, currentStock = 30, delta = -3)
        assertThat(result.stockAfter).isEqualTo(27)
    }

    @Test
    fun `return increases stock`() {
        val result = StockMovementCalculator.applyDelta(productId = 1, currentStock = 27, delta = 1)
        assertThat(result.stockAfter).isEqualTo(28)
    }

    @Test
    fun `full spec example sequence matches exactly`() {
        // Spec §3: initial 10, +20, -3, +1 -> 28
        var stock = 10
        stock = StockMovementCalculator.applyDelta(1, stock, 20).stockAfter
        stock = StockMovementCalculator.applyDelta(1, stock, -3).stockAfter
        stock = StockMovementCalculator.applyDelta(1, stock, 1).stockAfter
        assertThat(stock).isEqualTo(28)
    }

    @Test
    fun `selling more than available stock throws and does not silently go negative`() {
        assertThrows(InsufficientStockException::class.java) {
            StockMovementCalculator.applyDelta(productId = 1, currentStock = 5, delta = -10)
        }
    }

    @Test
    fun `insufficient stock exception carries correct details`() {
        val ex = assertThrows(InsufficientStockException::class.java) {
            StockMovementCalculator.applyDelta(productId = 42, currentStock = 5, delta = -10)
        }
        assertThat(ex.productId).isEqualTo(42)
        assertThat(ex.requested).isEqualTo(10)
        assertThat(ex.available).isEqualTo(5)
    }

    @Test
    fun `stock adjustment computes correct delta - decrease`() {
        // Spec §4: current 20, new 17 -> adjustment -3
        val result = StockMovementCalculator.adjustTo(currentStock = 20, newStock = 17)
        assertThat(result.delta).isEqualTo(-3)
        assertThat(result.stockAfter).isEqualTo(17)
    }

    @Test
    fun `stock adjustment computes correct delta - increase`() {
        val result = StockMovementCalculator.adjustTo(currentStock = 18, newStock = 28)
        assertThat(result.delta).isEqualTo(10)
        assertThat(result.stockAfter).isEqualTo(28)
    }

    @Test
    fun `stock adjustment to same value has zero delta`() {
        val result = StockMovementCalculator.adjustTo(currentStock = 15, newStock = 15)
        assertThat(result.delta).isEqualTo(0)
    }

    @Test
    fun `low stock detection - at threshold counts as low`() {
        assertThat(StockMovementCalculator.isLowStock(stockQuantity = 5, minimumStock = 5)).isTrue()
    }

    @Test
    fun `low stock detection - above threshold is not low`() {
        assertThat(StockMovementCalculator.isLowStock(stockQuantity = 6, minimumStock = 5)).isFalse()
    }

    @Test
    fun `low stock detection - below threshold is low`() {
        assertThat(StockMovementCalculator.isLowStock(stockQuantity = 0, minimumStock = 2)).isTrue()
    }
}
