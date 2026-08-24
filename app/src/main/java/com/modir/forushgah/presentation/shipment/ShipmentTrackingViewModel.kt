package com.modir.forushgah.presentation.shipment

import android.content.Intent
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.modir.forushgah.core.date.JalaliDateFormatter
import com.modir.forushgah.data.repository.ReferenceDataRepository
import com.modir.forushgah.data.repository.ShipmentTrackingRow
import com.modir.forushgah.data.repository.ShipmentTrackingUpdate
import com.modir.forushgah.domain.model.ShippingProvider
import com.modir.forushgah.domain.shipping.BulkSaveShipmentTrackingUseCase
import com.modir.forushgah.domain.shipping.GenerateTrackingMessageUseCase
import com.modir.forushgah.domain.shipping.SearchOrdersForShipmentUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Spec §25: tracking filters. */
enum class ShipmentFilter { ALL, NOT_SHIPPED, NO_TRACKING, SHIPPED }

/** One editable row. [trackingCode]/[providerId]/[dateText] are the live
 * values; *Original hold the database values for dirty detection. */
data class TrackingRowUi(
    val orderId: Long,
    val orderNumber: String,
    val customerId: Long?,
    val customerName: String,
    val customerMobile: String?,
    val providerId: Long?,
    val providerIdOriginal: Long?,
    val providerName: String?,
    val trackingCode: String,
    val trackingCodeOriginal: String?,
    val dateText: String,
    val shippedAtOriginal: Long?,
    val orderDate: Long,
    val isPurchase: Boolean,
) {
    val trackingCodeValue: String? get() = trackingCode.trim().ifEmpty { null }
    val shippedAt: Long? get() = if (dateText.isBlank()) null else JalaliDateFormatter.parseJalaliText(dateText)
    val hasTracking: Boolean get() = !trackingCode.isBlank()

    /** Spec §28: a row is dirty only when the seller actually changed it. */
    val dirty: Boolean
        get() = trackingCodeValue != trackingCodeOriginal ||
            (providerId ?: -1L) != (providerIdOriginal ?: -1L) ||
            (shippedAt ?: -1L) != (shippedAtOriginal ?: -1L)
}

data class ShipmentTrackingUiState(
    val isLoading: Boolean = true,
    val query: String = "",
    val filter: ShipmentFilter = ShipmentFilter.ALL,
    val providers: List<ShippingProvider> = emptyList(),
    val rows: List<TrackingRowUi> = emptyList(),
    val selectedOrderIds: Set<Long> = emptySet(),
    val isSaving: Boolean = false,
    val message: String? = null,
) {
    val dirtyCount: Int get() = rows.count { it.dirty }
    /** Selected rows that actually have a tracking code (for multi-share). */
    val shareableSelected: List<TrackingRowUi>
        get() = rows.filter { it.orderId in selectedOrderIds && it.hasTracking }
}

/**
 * «کدهای رهگیری ارسال» (Phase 3.1 Premium): bulk shipment tracking for many
 * orders from one screen. All database work goes through the transactional
 * use cases — Composables never touch Room.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class ShipmentTrackingViewModel @Inject constructor(
    private val searchOrders: SearchOrdersForShipmentUseCase,
    private val bulkSave: BulkSaveShipmentTrackingUseCase,
    private val generateMessage: GenerateTrackingMessageUseCase,
    private val referenceDataRepository: ReferenceDataRepository,
) : ViewModel() {

    private val query = MutableStateFlow("")
    private val filter = MutableStateFlow(ShipmentFilter.ALL)
    private val selection = MutableStateFlow<Set<Long>>(emptySet())
    private val message = MutableStateFlow<String?>(null)
    private val saving = MutableStateFlow(false)
    /** orderId → (tracking code, provider id, date text) for edited rows. */
    private val edits = MutableStateFlow<Map<Long, Triple<String, Long?, String>>>(emptyMap())

    private val rowsFlow = query.flatMapLatest { q -> searchOrders(q) }
    private val providersFlow = referenceDataRepository.observeShippingProviders()

    private data class BaseParts(
        val rows: List<ShipmentTrackingRow>,
        val providers: List<ShippingProvider>,
        val query: String,
        val filter: ShipmentFilter,
    )

    private val baseFlow = combine(rowsFlow, providersFlow, query, filter) { rows, providers, q, f ->
        BaseParts(rows, providers, q, f)
    }

    val uiState: StateFlow<ShipmentTrackingUiState> = combine(
        baseFlow, selection, edits, message, saving,
    ) { base, selected, editMap, msg, isSaving ->
        buildState(base, selected, editMap, msg, isSaving)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ShipmentTrackingUiState())

    private fun buildState(
        base: BaseParts,
        selected: Set<Long>,
        editMap: Map<Long, Triple<String, Long?, String>>,
        msg: String?,
        isSaving: Boolean,
    ): ShipmentTrackingUiState {
        val rowsUi = base.rows.map { row ->
            val (code, providerId, dateText) = editMap[row.orderId]
                ?: Triple(row.trackingCode.orEmpty(), row.providerId, row.shippedAt?.let { JalaliDateFormatter.formatJalali(it, false) } ?: "")
            TrackingRowUi(
                orderId = row.orderId,
                orderNumber = row.orderNumber,
                customerId = row.customerId,
                customerName = row.customerName.ifEmpty { "مشتری عمومی" },
                customerMobile = row.customerMobile,
                providerId = providerId,
                providerIdOriginal = row.providerId,
                providerName = base.providers.firstOrNull { it.id == providerId }?.name ?: row.providerName,
                trackingCode = code,
                trackingCodeOriginal = row.trackingCode,
                dateText = dateText,
                shippedAtOriginal = row.shippedAt,
                orderDate = row.orderDate,
                isPurchase = row.isPurchase,
            )
        }
        val filtered = when (base.filter) {
            ShipmentFilter.ALL -> rowsUi
            ShipmentFilter.NOT_SHIPPED -> rowsUi.filter { it.providerId == null }
            ShipmentFilter.NO_TRACKING -> rowsUi.filter { it.trackingCode.isBlank() }
            ShipmentFilter.SHIPPED -> rowsUi.filter { it.hasTracking || it.shippedAt != null }
        }
        // Spec §26: what needs shipment first — no tracking code, then no
        // provider, then newest.
        val sorted = filtered.sortedWith(
            compareByDescending<TrackingRowUi> { it.trackingCode.isBlank() }
                .thenByDescending { it.providerId == null }
                .thenByDescending { it.orderDate },
        )
        return ShipmentTrackingUiState(
            isLoading = false,
            query = base.query,
            filter = base.filter,
            providers = base.providers,
            rows = sorted,
            selectedOrderIds = selected,
            isSaving = isSaving,
            message = msg,
        )
    }

    // ---------- edits (spec §27/§28: many rows, partial save) ----------

    fun onQueryChange(v: String) {
        query.value = v
    }

    fun onFilterChange(f: ShipmentFilter) {
        filter.value = f
    }

    fun onTrackingCodeChange(orderId: Long, text: String) {
        val row = uiState.value.rows.firstOrNull { it.orderId == orderId } ?: return
        edits.update { it + (orderId to Triple(text, row.providerId, row.dateText)) }
    }

    fun onProviderChange(orderId: Long, providerId: Long?) {
        val row = uiState.value.rows.firstOrNull { it.orderId == orderId } ?: return
        edits.update { it + (orderId to Triple(row.trackingCode, providerId, row.dateText)) }
    }

    fun onDateChange(orderId: Long, text: String) {
        val row = uiState.value.rows.firstOrNull { it.orderId == orderId } ?: return
        edits.update { it + (orderId to Triple(row.trackingCode, row.providerId, text)) }
    }

    // ---------- selection (spec §35) ----------

    fun toggleSelection(orderId: Long) {
        selection.update { if (orderId in it) it - orderId else it + orderId }
    }

    fun selectAllVisible() {
        selection.update { it + uiState.value.rows.map { r -> r.orderId } }
    }

    fun clearSelection() {
        selection.update { emptySet() }
    }

    // ---------- bulk save (spec §27–§30) ----------

    /** Saves ONLY the modified rows, in one database transaction. */
    fun bulkSave() {
        val updates = uiState.value.rows
            .filter { it.dirty }
            .map {
                ShipmentTrackingUpdate(
                    orderId = it.orderId,
                    providerId = it.providerId,
                    trackingCode = it.trackingCodeValue,
                    shippedAt = it.shippedAt,
                )
            }
        if (updates.isEmpty()) return
        viewModelScope.launch {
            saving.value = true
            try {
                val saved = bulkSave(updates)
                message.value =
                    "${com.modir.forushgah.core.common.PersianNumberFormatter.toPersianDigits(saved.toString())} فاکتور ذخیره شد"
            } catch (e: Exception) {
                message.value = "ذخیره ناموفق بود؛ هیچ تغییری ثبت نشد"
            } finally {
                saving.value = false
            }
        }
    }

    fun onMessageShown() {
        message.value = null
    }

    // ---------- tracking message (spec §31/§32) ----------

    fun trackingMessage(row: TrackingRowUi): String? =
        if (row.hasTracking) {
            generateMessage(
                customerName = row.customerName,
                shippingProvider = row.providerName ?: "پست",
                trackingCode = row.trackingCode.trim(),
            )
        } else {
            null
        }

    /** SMS composer intent (spec §33) — null when the customer has no phone. */
    fun smsIntent(row: TrackingRowUi): Intent? =
        row.customerMobile?.trim()?.takeIf { it.isNotEmpty() }?.let { phone ->
            Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$phone")).apply {
                putExtra("sms_body", trackingMessage(row).orEmpty())
            }
        }

    /** Native share sheet intent (spec §34) — Android picks the targets. */
    fun shareIntent(row: TrackingRowUi): Intent? =
        if (row.hasTracking) {
            Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, trackingMessage(row).orEmpty())
                putExtra(Intent.EXTRA_SUBJECT, "کد رهگیری فاکتور ${row.orderNumber}")
            }
        } else {
            null
        }
}
