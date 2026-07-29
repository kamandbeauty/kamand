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
import ir.factoryar.app.widget.WidgetDataLoader
import ir.factoryar.core.domain.repository.ProductRepository
import kotlinx.coroutines.flow.first
import java.util.concurrent.TimeUnit

/** هشدار روزانه کالاهای رو به اتمام */
@HiltWorker
class LowStockWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted params: WorkerParameters,
    private val productRepository: ProductRepository,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = try {
        val lowStock = productRepository.observeLowStock().first()
        if (lowStock.isNotEmpty()) {
            NotificationHelper.notifyLowStock(
                context = applicationContext,
                count = lowStock.size,
                sampleNames = lowStock.take(3).map { it.name },
            )
        }
        Result.success()
    } catch (t: Throwable) {
        Result.retry()
    }

    companion object {
        private const val WORK_NAME = "factoryar_low_stock_daily"

        fun enqueue(workManager: WorkManager) {
            val request = PeriodicWorkRequestBuilder<LowStockWorker>(1, TimeUnit.DAYS).build()
            workManager.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}

/**
 * به‌روزرسانی دوره‌ای ویجت صفحه اصلی.
 * حداقل بازه مجاز WorkManager ۱۵ دقیقه است؛ به‌روزرسانی فوری پس از ثبت فاکتور
 * از طریق WidgetRefresher انجام می‌شود.
 */
@HiltWorker
class WidgetRefreshWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = try {
        if (WidgetDataLoader.hasWidgets(applicationContext)) {
            WidgetDataLoader.refreshAll(applicationContext)
        }
        Result.success()
    } catch (t: Throwable) {
        Result.success() // خطای ویجت نباید باعث retry پرهزینه شود
    }

    companion object {
        private const val WORK_NAME = "factoryar_widget_refresh"

        fun enqueue(workManager: WorkManager) {
            val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(30, TimeUnit.MINUTES).build()
            workManager.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}
