package ir.factoryar.core.domain.usecase

import ir.factoryar.core.domain.model.SalesReport
import ir.factoryar.core.domain.repository.InvoiceRepository
import javax.inject.Inject

class ObserveDashboardSummaryUseCase @Inject constructor(private val repo: InvoiceRepository) {
    operator fun invoke() = repo.observeDashboardSummary()
}

class BuildSalesReportUseCase @Inject constructor(private val repo: InvoiceRepository) {
    suspend operator fun invoke(from: Long, to: Long): SalesReport = repo.buildSalesReport(from, to)
}
