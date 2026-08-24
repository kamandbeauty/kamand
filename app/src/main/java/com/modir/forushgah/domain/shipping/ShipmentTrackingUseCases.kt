package com.modir.forushgah.domain.shipping

import com.modir.forushgah.data.repository.ShipmentTrackingRepository
import com.modir.forushgah.data.repository.ShipmentTrackingRow
import com.modir.forushgah.data.repository.ShipmentTrackingUpdate
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

/** Spec §38: clean domain operations for the tracking feature. The data
 * layer stays transactional; Composables never call the database directly. */

class SaveShipmentTrackingUseCase @Inject constructor(
    private val repository: ShipmentTrackingRepository,
) {
    suspend operator fun invoke(update: ShipmentTrackingUpdate) {
        repository.saveTracking(update)
    }
}

/** Transactional: all updates commit together or not at all (spec §29). */
class BulkSaveShipmentTrackingUseCase @Inject constructor(
    private val repository: ShipmentTrackingRepository,
) {
    suspend operator fun invoke(updates: List<ShipmentTrackingUpdate>): Int =
        repository.bulkSaveTracking(updates)
}

/** Database-level search by customer name (spec §24). */
class SearchOrdersForShipmentUseCase @Inject constructor(
    private val repository: ShipmentTrackingRepository,
) {
    operator fun invoke(query: String): Flow<List<ShipmentTrackingRow>> =
        repository.observeForTracking(query)
}
