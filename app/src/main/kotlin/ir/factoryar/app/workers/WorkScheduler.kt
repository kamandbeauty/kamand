package ir.factoryar.app.workers

import android.content.Context
import androidx.work.WorkManager
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class WorkScheduler @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    fun enqueueAll() {
        val wm = WorkManager.getInstance(context)
        RecurringInvoiceWorker.enqueue(wm)
        OverdueReminderWorker.enqueue(wm)
        BackupWorker.enqueue(wm)
        LowStockWorker.enqueue(wm)
        WidgetRefreshWorker.enqueue(wm)
    }
}
