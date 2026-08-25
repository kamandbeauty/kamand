package com.modir.forushgah

import android.app.Application
import com.modir.forushgah.data.sample.ReferenceDataSeeder
import com.modir.forushgah.data.sample.SampleDataSeeder
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

@HiltAndroidApp
class ModirApplication : Application() {

    @Inject
    lateinit var sampleDataSeeder: SampleDataSeeder

    @Inject
    lateinit var referenceDataSeeder: ReferenceDataSeeder

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        // Robolectric unit tests instantiate this Application without Hilt,
        // so the @Inject seeders are not initialized there — guard for it.
        if (!::referenceDataSeeder.isInitialized || !::sampleDataSeeder.isInitialized) return
        // Built-in reference data (channels/providers/payment methods) — real
        // configuration, idempotent, all builds.
        applicationScope.launch { referenceDataSeeder.seedBuiltIns() }
        // Debug-only sample data (spec §17): never runs in release builds and
        // never re-seeds a database that already has products.
        applicationScope.launch { sampleDataSeeder.seedIfEmpty() }
    }
}
