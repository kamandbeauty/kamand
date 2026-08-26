package com.modir.forushgah

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.designsystem.theme.ModirTheme
import com.modir.forushgah.data.local.AppDatabase
import com.modir.forushgah.data.local.entity.OrderEntity
import com.modir.forushgah.data.local.entity.ProductEntity
import com.modir.forushgah.presentation.navigation.ModirNavGraph
import dagger.hilt.android.testing.HiltAndroidTest
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import javax.inject.Inject

/**
 * Renders the REAL main navigation graph (bottom bar + dashboard start
 * destination, Hilt ViewModels, real Room database) in CI.
 *
 * This is the exact composition a user reaches when the app starts after
 * onboarding — the spot where the Phase 4.2.1 device crash (nested lazy
 * layouts on the dashboard) happened. Keeping this path under UI coverage
 * means any startup-screen crash fails CI with a stack trace.
 */
@HiltAndroidTest
@RunWith(RobolectricTestRunner::class)
@Config(application = TestApplication::class, qualifiers = "w1080dp-h1920dp")
class AppNavGraphUiTest {

    @get:Rule
    val compose = createComposeRule()

    @Inject
    lateinit var appDatabase: AppDatabase

    @Before
    fun seedDashboardData() = runBlocking {
        // A product with stock + a pending order → dashboard hasAnyData=true,
        // i.e. the stat-grid rendering path (not the empty state).
        appDatabase.productDao().insert(
            ProductEntity(
                name = "شامپو موی خشک ۴۰۰cc",
                sku = "SH-001",
                purchasePrice = Money(90_000),
                sellingPrice = Money(150_000),
                stockQuantity = 18,
                minimumStock = 5,
                createdAt = 0,
                updatedAt = 0,
            ),
        )
        appDatabase.orderDao().insertOrder(
            OrderEntity(
                orderNumber = "1001",
                customerId = null,
                orderDate = System.currentTimeMillis(),
                createdAt = 0,
                updatedAt = 0,
            ),
        )
    }

    @After
    fun closeDb() {
        appDatabase.close()
    }

    @Test
    fun `app main screen renders dashboard with data without crashing`() {
        compose.setContent {
            ModirTheme {
                ModirNavGraph()
            }
        }

        // Room flows emit asynchronously on the main looper — wait for the
        // snapshot to arrive before asserting.
        compose.waitUntil(15_000) {
            runCatching { compose.onNodeWithText("فروش امروز").assertExists() }.isSuccess
        }

        // Top bar, the (formerly crash-prone) stat grid and the bottom bar.
        compose.onNodeWithText("خانه").assertIsDisplayed()
        compose.onNodeWithText("فروش امروز").assertIsDisplayed()
        compose.onNodeWithText("ارزش موجودی کالا").assertIsDisplayed()
        compose.onNodeWithText("سفارش‌ها").assertIsDisplayed()
        compose.onNodeWithText("مالی").assertIsDisplayed()
    }

    @Test
    fun `financial tab shows the expense list without crashing`() {
        compose.setContent {
            ModirTheme {
                ModirNavGraph()
            }
        }
        // The «مالی» tab is not the start destination — navigate to it.
        compose.onNodeWithText("مالی").performClick()
        compose.waitUntil(15_000) {
            runCatching { compose.onNodeWithText("هزینه‌ها").assertExists() }.isSuccess
        }
        compose.onNodeWithText("هزینه‌ها").assertIsDisplayed()
        // The fresh (no-expense) state shows the empty-state CTA.
        compose.onNodeWithText("هنوز هزینه‌ای ثبت نشده").assertIsDisplayed()
    }
}
