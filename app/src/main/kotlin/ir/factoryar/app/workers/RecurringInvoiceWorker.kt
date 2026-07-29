package ir.factoryar.app.workers

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import ir.factoryar.app.notifications.NotificationHelper
import ir.factoryar.core.common.util.PersianFormatter.formatMoneyWithUnit
import ir.factoryar.core.common.util.CurrencyUnit
import ir.factoryar.core.domain.model.DebtorSort
import ir.factoryar.core.domain.repository.DebtorRepository
import ir.factoryar.core.domain.repository.RecurringRepository
import ir.factoryar.core.domain.repository.SettingsRepository
import kotlinx.coroutines.flow.first
import java.util.concurrent.TimeUnit

/** بررسی روزانه قالب‌های دوره‌ای → صدور خودکار فاکتور + نوتیفیکیشن محلی */
@HiltWorker
class RecurringInvoiceWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted params: WorkerParameters,
    private val recurringRepository: RecurringRepository,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = try {
        val count = recurringRepository.generateDueInvoices(System.currentTimeMillis())
        if (count > 0) {
            NotificationHelper.notifyRecurringInvoices(applicationContext, count)
        }
        Result.success()
    } catch (t: Throwable) {
        Result.retry()
    }

    companion object {
        private const val WORK_NAME = "factoryar_recurring_daily"

        fun enqueue(workManager: WorkManager) {
            val request = PeriodicWorkRequestBuilder<RecurringInvoiceWorker>(1, TimeUnit.DAYS)
                .build()
            workManager.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}

/** یادآوری هفتگی بدهی‌های معوق مشتریان */
@HiltWorker
class OverdueReminderWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted params: WorkerParameters,
    private val debtorRepository: DebtorRepository,
    private val settingsRepository: SettingsRepository,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = try {
        val summary = debtorRepository.getDebtors(DebtorSort.OVERDUE_DAYS, onlyOverdue = true)
        if (summary.debtors.isNotEmpty()) {
            val unit = CurrencyUnit.fromName(settingsRepository.settings.first().currencyUnit)
            NotificationHelper.notifyOverdueDebts(
                context = applicationContext,
                customerCount = summary.overdueCustomerCount,
                totalLabel = formatMoneyWithUnit(summary.totalOverdue, unit),
                topDebtorName = summary.debtors.firstOrNull()?.customer?.name.orEmpty(),
                maxOverdueDays = summary.debtors.firstOrNull()?.maxOverdueDays ?: 0,
            )
        }
        Result.success()
    } catch (t: Throwable) {
        Result.retry()
    }

    companion object {
        private const val WORK_NAME = "factoryar_overdue_weekly"

        fun enqueue(workManager: WorkManager) {
            val request = PeriodicWorkRequestBuilder<OverdueReminderWorker>(7, TimeUnit.DAYS)
                .build()
            workManager.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}
