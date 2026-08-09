package ir.factoryar.app

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import dagger.hilt.android.HiltAndroidApp
import ir.factoryar.app.notifications.NotificationHelper
import ir.factoryar.app.widget.WidgetRefresher
import ir.factoryar.app.workers.WorkScheduler
import javax.inject.Inject

@HiltAndroidApp
class FactorYarApplication : Application(), Configuration.Provider {

    @Inject
    lateinit var workerFactory: HiltWorkerFactory

    @Inject
    lateinit var workScheduler: WorkScheduler

    @Inject
    lateinit var widgetRefresher: WidgetRefresher

    override fun onCreate() {
        super.onCreate()
        NotificationHelper.createChannels(this)
        workScheduler.enqueueAll()
        // ویجت صفحه اصلی با تغییر داده‌های مالی/تم به‌روز می‌شود
        widgetRefresher.start()
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()
}
