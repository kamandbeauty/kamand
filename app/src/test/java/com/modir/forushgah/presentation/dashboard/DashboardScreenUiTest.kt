package com.modir.forushgah.presentation.dashboard

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import com.modir.forushgah.core.common.Money
import com.modir.forushgah.core.designsystem.theme.ModirTheme
import com.modir.forushgah.domain.model.ActionSeverity
import com.modir.forushgah.domain.model.DashboardSnapshot
import com.modir.forushgah.domain.model.TodayActionItem
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Renders the REAL dashboard composition in CI (JVM/Robolectric).
 *
 * Background: a LazyVerticalGrid nested inside a LazyColumn item crashed on
 * physical devices right after onboarding (the first data screen the user
 * ever sees). Robolectric database tests never render Compose, so the crash
 * only appeared on a real device. This test keeps the startup screen under
 * UI coverage so any layout-level crash fails CI with a stack trace.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1080dp-h1920dp")
class DashboardScreenUiTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `dashboard with data renders stat grid and actions without crashing`() {
        val snapshot = DashboardSnapshot(
            todaySales = Money(500_000),
            monthSales = Money(5_000_000),
            netProfit = Money(1_000_000),
            todayOrderCount = 3,
            pendingOrderCount = 2,
            totalReceivables = Money(800_000),
            totalPayables = Money(200_000),
            inventoryValue = Money(10_000_000),
            todayActions = listOf(
                TodayActionItem(ActionSeverity.CRITICAL, "۲ مطالبه سررسید شده", 2),
                TodayActionItem(ActionSeverity.MEDIUM, "کالاهای رو به اتمام: ۱ کالا", 1),
            ),
        )

        compose.setContent {
            ModirTheme {
                DashboardScreen(state = DashboardUiState.Content(snapshot), onStartFirstOrder = {})
            }
        }

        // The stat grid (previously a nested lazy layout that crashed on
        // devices) and the action section must actually render.
        compose.onNodeWithText("فروش امروز").assertIsDisplayed()
        compose.onNodeWithText("فروش این ماه").assertIsDisplayed()
        compose.onNodeWithText("سود خالص").assertIsDisplayed()
        compose.onNodeWithText("سفارش‌های امروز").assertIsDisplayed()
        compose.onNodeWithText("سفارش‌های در انتظار").assertIsDisplayed()
        compose.onNodeWithText("مطالبات").assertIsDisplayed()
        compose.onNodeWithText("بدهی‌ها").assertIsDisplayed()
        compose.onNodeWithText("ارزش موجودی کالا").assertIsDisplayed()
        compose.onNodeWithText("امروز چه کار کنم؟").assertIsDisplayed()
    }

    @Test
    fun `dashboard empty state renders without crashing`() {
        compose.setContent {
            ModirTheme {
                DashboardScreen(state = DashboardUiState.Content(DashboardSnapshot.EMPTY), onStartFirstOrder = {})
            }
        }
        compose.onNodeWithText("هنوز چیزی ثبت نشده").assertIsDisplayed()
    }
}
