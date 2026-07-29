package ir.factoryar.core.domain.usecase

import ir.factoryar.core.domain.model.InvoiceCalculator
import ir.factoryar.core.domain.model.InvoiceTotals
import ir.factoryar.core.domain.model.InvoiceType
import ir.factoryar.core.domain.model.InvoiceWithDetails
import ir.factoryar.core.domain.repository.InvoiceRepository
import javax.inject.Inject

/** محاسبه جمع فاکتور (خالص و بدون وابستگی اندروید — قابل تست) */
class CalculateInvoiceTotalsUseCase @Inject constructor() {
    operator fun invoke(details: InvoiceWithDetails): InvoiceTotals =
        InvoiceCalculator.calculate(details.items, details.invoice.globalDiscount)
}

class ObserveInvoicesUseCase @Inject constructor(private val repo: InvoiceRepository) {
    operator fun invoke(
        type: InvoiceType? = null,
        status: ir.factoryar.core.domain.model.PaymentStatus? = null,
        query: String = "",
        overdueOnly: Boolean = false,
    ) = repo.observeInvoices(type, status, query, overdueOnly)
}

class GetInvoiceUseCase @Inject constructor(private val repo: InvoiceRepository) {
    operator fun invoke(id: Long) = repo.observeInvoice(id)
}

class SaveInvoiceUseCase @Inject constructor(private val repo: InvoiceRepository) {
    suspend operator fun invoke(details: InvoiceWithDetails): Long = repo.saveInvoice(details)
}

class DeleteInvoiceUseCase @Inject constructor(private val repo: InvoiceRepository) {
    suspend operator fun invoke(id: Long) = repo.deleteInvoice(id)
}
