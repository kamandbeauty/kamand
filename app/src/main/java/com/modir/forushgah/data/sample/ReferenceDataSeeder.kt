package com.modir.forushgah.data.sample

import com.modir.forushgah.data.local.dao.PaymentMethodDao
import com.modir.forushgah.data.local.dao.SalesChannelDao
import com.modir.forushgah.data.local.dao.ShippingProviderDao
import com.modir.forushgah.data.local.entity.PaymentMethodEntity
import com.modir.forushgah.data.local.entity.SalesChannelEntity
import com.modir.forushgah.data.local.entity.ShippingProviderEntity
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Built-in reference data (spec §8/§9/§10). Unlike the debug-only sample data,
 * this is real configuration, not fake data: default sales channels, shipping
 * providers and payment methods every store starts with. Idempotent (unique
 * name), safe to run on every startup, and users can extend all three lists
 * later without touching the calculation logic.
 */
@Singleton
class ReferenceDataSeeder @Inject constructor(
    private val salesChannelDao: SalesChannelDao,
    private val shippingProviderDao: ShippingProviderDao,
    private val paymentMethodDao: PaymentMethodDao,
) {

    private val builtInSalesChannels = listOf("اینستاگرام", "وب‌سایت", "باسلام", "ترب", "اسنپ‌پی", "سایر")
    private val builtInShippingProviders = listOf("پست", "تیپاکس", "پیک", "سایر")
    private val builtInPaymentMethods = listOf("نقدی", "کارت‌به‌کارت", "کارت بانکی", "درگاه", "اقساطی", "سایر")

    suspend fun seedBuiltIns() {
        for (name in builtInSalesChannels) {
            if (salesChannelDao.countByName(name) == 0) {
                salesChannelDao.insert(SalesChannelEntity(name = name, isBuiltIn = true))
            }
        }
        for (name in builtInShippingProviders) {
            if (shippingProviderDao.countByName(name) == 0) {
                shippingProviderDao.insert(ShippingProviderEntity(name = name))
            }
        }
        for (name in builtInPaymentMethods) {
            if (paymentMethodDao.countByName(name) == 0) {
                paymentMethodDao.insert(PaymentMethodEntity(name = name, isBuiltIn = true))
            }
        }
    }
}
