package com.modir.forushgah.data.repository

import com.modir.forushgah.data.local.dao.PaymentMethodDao
import com.modir.forushgah.data.local.dao.SalesChannelDao
import com.modir.forushgah.data.local.dao.ShippingProviderDao
import com.modir.forushgah.data.local.entity.PaymentMethodEntity
import com.modir.forushgah.data.local.entity.SalesChannelEntity
import com.modir.forushgah.data.local.entity.ShippingProviderEntity
import com.modir.forushgah.domain.model.PaymentMethod
import com.modir.forushgah.domain.model.SalesChannel
import com.modir.forushgah.domain.model.ShippingProvider
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/** Read access to the user-extensible reference data (spec §8/§9/§10):
 * sales channels, shipping providers, payment methods. Generic on purpose —
 * nothing here is tied to a specific external platform. */
@Singleton
class ReferenceDataRepository @Inject constructor(
    private val salesChannelDao: SalesChannelDao,
    private val shippingProviderDao: ShippingProviderDao,
    private val paymentMethodDao: PaymentMethodDao,
) {
    fun observeSalesChannels(): Flow<List<SalesChannel>> =
        salesChannelDao.observeAll().map { list -> list.map { it.toDomain() } }

    fun observeShippingProviders(): Flow<List<ShippingProvider>> =
        shippingProviderDao.observeAll().map { list -> list.map { it.toDomain() } }

    fun observePaymentMethods(): Flow<List<PaymentMethod>> =
        paymentMethodDao.observeAll().map { list -> list.map { it.toDomain() } }

    /** Custom-channel creation for later phases (UI comes with Phase 5's
     * settlement engine); the insert path already exists. */
    suspend fun insertSalesChannel(name: String): Long =
        salesChannelDao.insert(SalesChannelEntity(name = name.trim(), isBuiltIn = false))

    suspend fun insertShippingProvider(name: String): Long =
        shippingProviderDao.insert(ShippingProviderEntity(name = name.trim()))

    suspend fun insertPaymentMethod(name: String): Long =
        paymentMethodDao.insert(PaymentMethodEntity(name = name.trim(), isBuiltIn = false))
}

private fun SalesChannelEntity.toDomain() = SalesChannel(id = id, name = name, defaultCommissionPercent = defaultCommissionPercent, isBuiltIn = isBuiltIn)
private fun ShippingProviderEntity.toDomain() = ShippingProvider(id = id, name = name)
private fun PaymentMethodEntity.toDomain() = PaymentMethod(id = id, name = name, isBuiltIn = isBuiltIn)
