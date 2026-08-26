package com.modir.forushgah

import android.app.Application
import dagger.hilt.android.testing.HiltTestApplication

/**
 * Test-only application for @HiltAndroidTest: the real Hilt graph (and the
 * real Room database builder) runs, but ModirApplication's sample-data
 * seeders do NOT run, so UI tests start from a known state.
 */
@HiltTestApplication
class HiltTestApplication : Application()
