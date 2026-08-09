package ir.factoryar.feature.invoices

import android.content.Context
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import ir.factoryar.core.common.util.CurrencyUnit
import ir.factoryar.core.common.util.onFailure
import ir.factoryar.core.common.util.onSuccess
import ir.factoryar.core.domain.model.InvoiceWithDetails
import ir.factoryar.core.domain.model.PaymentStatus
import ir.factoryar.core.domain.repository.BusinessRepository
import ir.factoryar.core.domain.repository.InvoiceRepository
import ir.factoryar.core.domain.repository.SettingsRepository
import ir.factoryar.core.domain.repository.AppSettings
import ir.factoryar.core.domain.usecase.GetInvoiceUseCase
import ir.factoryar.core.pdf.InvoiceImageGenerator
import ir.factoryar.core.pdf.InvoicePdfGenerator
import ir.factoryar.core.pdf.PdfSharer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class InvoiceDetailUiState(
    val details: InvoiceWithDetails? = null,
    val businessName: String = "",
    val businessLogo: String? = null,
    val businessPhone: String = "",
    val businessTerms: String = "",
    val settings: AppSettings = AppSettings(),
    val isBusy: Boolean = false,
)

sealed interface InvoiceDetailEvent {
    data class Message(val text: String) : InvoiceDetailEvent
    data object Deleted : InvoiceDetailEvent
}

@HiltViewModel
class InvoiceDetailViewModel @Inject constructor(
    getInvoice: GetInvoiceUseCase,
    private val invoiceRepository: InvoiceRepository,
    private val businessRepository: BusinessRepository,
    private val settingsRepository: SettingsRepository,
    @ApplicationContext private val context: Context,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    val invoiceId: Long = savedStateHandle.get<Long>("invoiceId") ?: 0L

    private val pdfGenerator by lazy { InvoicePdfGenerator(context) }
    private val imageGenerator by lazy { InvoiceImageGenerator(context) }

    private val busy = MutableStateFlow(false)

    val uiState: StateFlow<InvoiceDetailUiState> = combine(
        getInvoice(invoiceId),
        businessRepository.observeActiveProfile(),
        settingsRepository.settings,
        busy,
    ) { details, profile, settings, isBusy ->
        InvoiceDetailUiState(
            details = details,
            businessName = profile?.name ?: "",
            businessLogo = profile?.logoPath,
            businessPhone = profile?.phone ?: "",
            businessTerms = profile?.defaultTerms ?: "",
            settings = settings,
            isBusy = isBusy,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), InvoiceDetailUiState())

    private val _events = MutableSharedFlow<InvoiceDetailEvent>()
    val events: SharedFlow<InvoiceDetailEvent> = _events

    fun sharePdf() {
        val state = uiState.value
        val details = state.details ?: return
        viewModelScope.launch(Dispatchers.IO) {
            busy.value = true
            runCatching {
                val profile = businessRepository.getActiveProfile()
                val file = pdfGenerator.generate(
                    details = details,
                    profile = profile,
                    currencyUnit = CurrencyUnit.fromName(state.settings.currencyUnit),
                    showWatermark = !state.settings.isPremium,
                )
                file
            }.onSuccess { file ->
                PdfSharer.share(context, file)
            }.onFailure {
                _events.emit(InvoiceDetailEvent.Message("خطا در ساخت PDF: ${it.message}"))
            }
            busy.value = false
        }
    }

    /** خروجی تصویری (JPG) — مناسب ارسال سریع در پیام‌رسان‌ها */
    fun shareImage() {
        val state = uiState.value
        val details = state.details ?: return
        viewModelScope.launch(Dispatchers.IO) {
            busy.value = true
            runCatching {
                val profile = businessRepository.getActiveProfile()
                imageGenerator.generate(
                    details = details,
                    profile = profile,
                    currencyUnit = CurrencyUnit.fromName(state.settings.currencyUnit),
                    showWatermark = !state.settings.isPremium,
                )
            }.onSuccess { file ->
                PdfSharer.share(context, file, "اشتراک‌گذاری تصویر فاکتور")
            }.onFailure {
                _events.emit(InvoiceDetailEvent.Message("خطا در ساخت تصویر: ${it.message}"))
            }
            busy.value = false
        }
    }

    /** اشتراک همزمان PDF و تصویر — کاربر در اپ مقصد انتخاب می‌کند */
    fun shareBoth() {
        val state = uiState.value
        val details = state.details ?: return
        viewModelScope.launch(Dispatchers.IO) {
            busy.value = true
            runCatching {
                val profile = businessRepository.getActiveProfile()
                val unit = CurrencyUnit.fromName(state.settings.currencyUnit)
                val watermark = !state.settings.isPremium
                val pdf = pdfGenerator.generate(details, profile, unit, watermark)
                // تصویر از همان PDF ساخته می‌شود تا دوباره رسم نشود
                val jpg = imageGenerator.generate(details, profile, unit, watermark, pdfFile = pdf)
                listOf(pdf, jpg)
            }.onSuccess { files ->
                PdfSharer.shareMultiple(context, files)
            }.onFailure {
                _events.emit(InvoiceDetailEvent.Message("خطا در ساخت خروجی: ${it.message}"))
            }
            busy.value = false
        }
    }

    /** نمایش PDF در اپ پیش‌فرض دستگاه */
    fun openPdf() {
        val state = uiState.value
        val details = state.details ?: return
        viewModelScope.launch(Dispatchers.IO) {
            busy.value = true
            runCatching {
                val profile = businessRepository.getActiveProfile()
                pdfGenerator.generate(
                    details = details,
                    profile = profile,
                    currencyUnit = CurrencyUnit.fromName(state.settings.currencyUnit),
                    showWatermark = !state.settings.isPremium,
                )
            }.onSuccess { file ->
                PdfSharer.view(context, file)
            }.onFailure {
                _events.emit(InvoiceDetailEvent.Message("خطا در باز کردن PDF: ${it.message}"))
            }
            busy.value = false
        }
    }

    fun markPaid() {
        val details = uiState.value.details ?: return
        viewModelScope.launch {
            invoiceRepository.setPayment(details.invoice.id, PaymentStatus.PAID, details.invoice.grandTotal)
        }
    }

    fun delete() {
        viewModelScope.launch {
            invoiceRepository.deleteInvoice(invoiceId)
            _events.emit(InvoiceDetailEvent.Deleted)
        }
    }
}
