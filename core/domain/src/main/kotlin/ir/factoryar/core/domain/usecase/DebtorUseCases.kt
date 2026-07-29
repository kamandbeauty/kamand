package ir.factoryar.core.domain.usecase

import ir.factoryar.core.domain.model.DebtorEntry
import ir.factoryar.core.domain.model.DebtorSort
import ir.factoryar.core.domain.model.ReminderMessageBuilder
import ir.factoryar.core.domain.repository.BusinessRepository
import ir.factoryar.core.domain.repository.DebtorRepository
import kotlinx.coroutines.flow.first
import javax.inject.Inject

class ObserveDebtorsUseCase @Inject constructor(private val repo: DebtorRepository) {
    operator fun invoke(sort: DebtorSort = DebtorSort.AMOUNT, onlyOverdue: Boolean = false) =
        repo.observeDebtors(sort, onlyOverdue)
}

/**
 * تولید متن آماده یادآوری بدهی برای ارسال با Share Intent.
 * قالب‌بندی مبلغ/تاریخ از بیرون تزریق می‌شود تا Domain مستقل بماند.
 */
class BuildReminderMessageUseCase @Inject constructor(
    private val businessRepository: BusinessRepository,
) {
    suspend operator fun invoke(
        entry: DebtorEntry,
        formatMoney: (Long) -> String,
        formatDate: (Long) -> String,
    ): String {
        val profile = businessRepository.observeActiveProfile().first()
        return ReminderMessageBuilder.build(
            entry = entry,
            businessName = profile?.name.orEmpty(),
            businessPhone = profile?.phone.orEmpty(),
            formatMoney = formatMoney,
            formatDate = formatDate,
        )
    }
}
