package ir.factoryar.core.data.repository

import ir.factoryar.core.data.mapper.toDomain
import ir.factoryar.core.data.mapper.toEntity
import ir.factoryar.core.database.dao.BusinessDao
import ir.factoryar.core.domain.model.BusinessProfile
import ir.factoryar.core.domain.repository.BusinessRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BusinessRepositoryImpl @Inject constructor(
    private val businessDao: BusinessDao,
) : BusinessRepository {

    override fun observeActiveProfile(): Flow<BusinessProfile?> =
        businessDao.observeActive().map { it?.toDomain() }

    override fun observeAll(): Flow<List<BusinessProfile>> =
        businessDao.observeAll().map { list -> list.map { it.toDomain() } }

    override suspend fun getActiveProfile(): BusinessProfile =
        businessDao.getActive()?.toDomain() ?: BusinessProfile(name = "کسب‌وکار من", isActive = true)

    override suspend fun save(profile: BusinessProfile): Long {
        val id = businessDao.upsert(profile.toEntity())
        if (profile.isActive) {
            businessDao.clearActive()
            businessDao.setActive(if (profile.id == 0L) id else profile.id)
        }
        return id
    }

    override suspend fun setActive(id: Long) {
        businessDao.clearActive()
        businessDao.setActive(id)
    }
}
